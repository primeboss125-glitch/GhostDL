import os
import re
import urllib.parse
import threading
import time
import requests
from flask import Flask, request, jsonify
from flask_cors import CORS
from concurrent.futures import ThreadPoolExecutor

app = Flask(__name__)
CORS(app)

# Track active downloads so the web UI can poll for progress
active_tasks = {}
task_counter = 0

DOWNLOAD_DIR = os.path.expanduser("~/storage/downloads/GhostDL")
if not os.path.exists(DOWNLOAD_DIR):
    os.makedirs(DOWNLOAD_DIR, exist_ok=True)

@app.route('/api/ping', methods=['GET'])
def ping():
    return jsonify({"status": "online", "message": "Ghost Engine Active"})

@app.route('/api/progress', methods=['GET'])
def get_progress():
    return jsonify(active_tasks)

def threaded_download(task_id, direct_url, filename, total_size, num_threads):
    filepath = os.path.join(DOWNLOAD_DIR, filename)
    active_tasks[task_id]['state'] = 'downloading'
    
    try:
        # Pre-allocate the file size on disk
        with open(filepath, "wb") as f:
            f.truncate(total_size)
            
        chunk_size = total_size // num_threads
        
        def download_chunk(start, end, thread_id):
            headers = {'Range': f'bytes={start}-{end}'}
            res = requests.get(direct_url, headers=headers, stream=True, timeout=15)
            
            with open(filepath, "r+b") as f:
                f.seek(start)
                for chunk in res.iter_content(chunk_size=8192):
                    if chunk:
                        if active_tasks[task_id]['state'] == 'cancelled':
                            return
                        f.write(chunk)
                        active_tasks[task_id]['downloaded'] += len(chunk)

        futures = []
        with ThreadPoolExecutor(max_workers=num_threads) as executor:
            for i in range(num_threads):
                start = i * chunk_size
                end = total_size - 1 if i == num_threads - 1 else (start + chunk_size - 1)
                futures.append(executor.submit(download_chunk, start, end, i))
                
        for future in futures:
            future.result() # Wait for all threads to finish

        if active_tasks[task_id]['state'] != 'cancelled':
            active_tasks[task_id]['state'] = 'completed'
            active_tasks[task_id]['progress'] = 100
            
    except Exception as e:
        active_tasks[task_id]['state'] = 'failed'
        active_tasks[task_id]['error'] = str(e)

@app.route('/api/download', methods=['POST'])
def start_download():
    global task_counter
    data = request.json
    url = data.get('url')
    threads = int(data.get('threads', 4))
    
    if not url or 'mediafire.com' not in url:
        return jsonify({'error': 'Invalid MediaFire URL'}), 400
        
    try:
        # 1. Extract Direct Link
        headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
        res = requests.get(url, headers=headers, timeout=10)
        match = re.search(r'https?://(?:download[^.]*)\.mediafire\.com/[^\s"\'<>]+', res.text, re.IGNORECASE)
        
        if not match:
            return jsonify({'error': 'Direct link not found.'}), 404
            
        direct_url = match.group(0).rstrip('"\'')
        
        # 2. Get File Info
        head_res = requests.head(direct_url, headers=headers, timeout=10)
        total_size = int(head_res.headers.get('content-length', 0))
        
        filename = "downloaded_file.bin"
        try:
            filename = urllib.parse.unquote(direct_url.split('/')[-1].split('?')[0])
        except:
            pass

        # 3. Register Task
        task_counter += 1
        task_id = str(task_counter)
        
        active_tasks[task_id] = {
            'filename': filename,
            'total_size': total_size,
            'downloaded': 0,
            'progress': 0,
            'state': 'queued',
            'threads': threads
        }
        
        # 4. Start Background Thread
        threading.Thread(target=threaded_download, args=(task_id, direct_url, filename, total_size, threads)).start()
        
        return jsonify({'success': True, 'task_id': task_id, 'filename': filename})
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print("\n[System] 🔥 GHOST DL Local Daemon Active.")
    print("[System] Waiting for commands from Web UI...\n")
    app.run(host='127.0.0.1', port=5000)