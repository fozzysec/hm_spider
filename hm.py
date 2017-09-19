#!/usr/bin/env python3
from gevent import monkey
monkey.patch_all()
import requests
import sys
import json
from threading import Thread
from concurrent.futures import ThreadPoolExecutor
from queue import Queue
from requests.adapters import HTTPAdapter
import lxml.html
import re
from os.path import basename

URL = "https://haimanchajian.com/jx3/secret/posts/{}"
UA = 'Mozilla/5.0 (Windows NT 6.3; Trident/7.0; rv:11.0) like Gecko'

start_id = int(sys.argv[1])
end_id = int(sys.argv[2])
filename = sys.argv[3]

def init():
    session = requests.Session()
    session.headers.update({'user-agent': UA})
    session.mount('https://', HTTPAdapter(max_retries=3))
    write_queue = Queue()
    fetch_queue = Queue()
    download_queue = Queue()
    process_pool = ThreadPoolExecutor(max_workers=5)
    fetch_pool = ThreadPoolExecutor(max_workers=1)
    write_pool = ThreadPoolExecutor(max_workers=1)
    download_pool = ThreadPoolExecutor(max_workers=1)

    return {
            'session': session,
            'write': write_queue,
            'fetch': fetch_queue,
            'download': download_queue,
            'process_pool': process_pool,
            'fetch_pool': fetch_pool,
            'write_pool': write_pool,
            'download_pool': download_pool
            }

def check_post(post_id, session, queue):
    response = session.head(URL.format(post_id))
    if response.status_code is 200:
        queue.put(post_id)

def fetch_post(session, fetch_queue, download_queue, write_queue):
    while(True):
        post_id = fetch_queue.get(block=True)
        if post_id is 'STOP':
            download_queue.put('STOP')
            write_queue.put('STOP')
            break
        doc = lxml.html.fromstring(session.get(URL.format(post_id), timeout=5).text)
        try:
            author = doc.xpath('//span[@class="post-item-username"]/text()')[0]
            content = doc.xpath('//div[@class="post-item-body"]/text()')[0]
            content = re.sub('[\s(\\n)]', '', content)
            pic_nodes = doc.xpath('//div[contains(@class, "post-item-pic")]')
            images = []
            audio = None
            for node in pic_nodes:
                if node.xpath('./img'):
                    images.append(node.xpath('./img/@src')[0].rsplit('/', 1)[0])
                if node.xpath('./audio'):
                    audio = doc.xpath('./audio/@src')[0]
        except IndexError:
            continue
        for url in images:
            download_queue.put(url)
        record = {
                'id': post_id,
                'author': author,
                'content': content,
                'images': images,
                'audio': audio
                }
        print(record)
        write_queue.put(record)

def write_json(filename, queue):
    with open(filename, 'w', encoding='utf8') as fh:
        while(True):
            record = queue.get(block=True)
            if record is 'STOP':
                break
            fh.write(json.dumps(record))
            fh.write("\n")

def download_images(session, queue):
    while(True):
        url = queue.get(block=True)
        if url is 'STOP':
            break
        response = session.get(url, stream=True)
        with open("{}/{}".format('images', basename(url)), 'wb') as f:
            for chunk in response.iter_content(chunk_size=1024):
                f.write(chunk)
            print("Download image %s complete." % basename(url))

init_vars = init()
init_vars['fetch_pool'].submit(fetch_post, init_vars['session'], init_vars['fetch'], init_vars['download'], init_vars['write'])
init_vars['download_pool'].submit(download_images, init_vars['session'], init_vars['download'])
init_vars['write_pool'].submit(write_json, filename, init_vars['write'])
for i in range(start_id, end_id + 1):
    init_vars['process_pool'].submit(check_post, i, init_vars['session'], init_vars['fetch'])

init_vars['process_pool'].shutdown()
init_vars['fetch'].put('STOP')




init_vars['fetch_pool'].shutdown()

init_vars['write_pool'].shutdown()
init_vars['download_pool'].shutdown()
