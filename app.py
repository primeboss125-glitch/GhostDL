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
            headers = {'Range': f'bytes={start}-{end}', 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
            try:
                res = requests.get(direct_url, headers=headers, stream=True, timeout=15)
                res.raise_for_status()
                
                with open(filepath, "r+b") as f_out:
                    f_out.seek(start)
                    for chunk in res.iter_content(chunk_size=64*1024):
                        if chunk:
                            f_out.write(chunk)
                            active_tasks[task_id]['downloaded'] += len(chunk)
            except Exception as e:
                active_tasks[task_id]['error'] = str(e)
                active_tasks[task_id]['state'] = 'failed'

        threads_list = []
        for i in range(num_threads):
            start = i * chunk_size
            end = (start + chunk_size - 1) if i < num_threads - 1 else total_size - 1
            t = threading.Thread(target=download_chunk, args=(start, end, i))
            threads_list.append(t)
            t.start()
            
        for t in threads_list:
            t.join()
            
        if active_tasks[task_id]['state'] != 'failed':
            active_tasks[task_id]['state'] = 'completed'
            active_tasks[task_id]['downloaded'] = total_size
    except Exception as e:
        active_tasks[task_id]['error'] = str(e)
        active_tasks[task_id]['state'] = 'failed'

@app.route('/api/extract', methods=['POST'])
def extract_link():
    global task_counter
    data = request.json
    url = data.get('url')
    threads = int(data.get('threads', 4))
    
    if not url or 'mediafire.com' not in url:
        return jsonify({'error': 'Invalid or missing MediaFire URL'}), 400
        
    try:
        headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
        res = requests.get(url, headers=headers, timeout=10)
        res.raise_for_status()
        
        match = re.search(r'https?://(?:download[^.]*)\.mediafire\.com/[^\s"\'<>]+', res.text, re.IGNORECASE)
        
        if not match:
            return jsonify({'error': 'Direct link not found.'}), 404
            
        direct_url = match.group(0).rstrip('"\'')
        
        head_res = requests.head(direct_url, headers=headers, timeout=10)
        total_size = int(head_res.headers.get('content-length', 0))
        
        filename = "downloaded_file.bin"
        try:
            filename = urllib.parse.unquote(direct_url.split('/')[-1].split('?')[0])
        except:
            pass

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
        
        threading.Thread(target=threaded_download, args=(task_id, direct_url, filename, total_size, threads)).start()
        
        return jsonify({'success': True, 'task_id': task_id, 'filename': filename})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print("[System] \033[91m GHOST DL Local Daemon Active.\033[0m")
    print("[System] Waiting for commands from Web UI...\n")
    app.run(host='0.0.0.0', port=5000, debug=False)