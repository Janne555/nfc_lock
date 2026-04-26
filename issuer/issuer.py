import asyncio
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

import tornado.ioloop
import tornado.web
import yaml

config = {}
executor = ThreadPoolExecutor(max_workers=1)


def resource_path(relative):
    base = getattr(sys, '_MEIPASS', os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base, relative)


def bin_path(name):
    return os.path.join(config.get('bin_dir', '.'), name)


def nfc_args():
    device = config.get('nfc_device', '')
    return [device] if device else []


def _clean_env():
    env = os.environ.copy()
    env.pop('LD_LIBRARY_PATH', None)
    return env


def run_process(cmd, stdin, timeout):
    print(f'[issuer] running: {cmd}', flush=True)
    try:
        r = subprocess.run(cmd, input=stdin, capture_output=True, timeout=timeout, env=_clean_env())
        stdout = r.stdout.decode(errors='replace')
        stderr = r.stderr.decode(errors='replace')
        print(f'[issuer] exit={r.returncode} stdout={stdout!r} stderr={stderr!r}', flush=True)
        return {
            'stdout': stdout,
            'stderr': stderr,
            'ok': r.returncode == 0,
        }
    except subprocess.TimeoutExpired:
        print('[issuer] timed out', flush=True)
        return {'error': 'Timed out — is a card present?', 'ok': False}
    except FileNotFoundError:
        print(f'[issuer] binary not found: {cmd[0]}', flush=True)
        return {'error': f'Binary not found: {cmd[0]}', 'ok': False}


class IndexHandler(tornado.web.RequestHandler):
    def get(self):
        with open(resource_path('static/index.html'), 'rb') as f:
            self.write(f.read())


class RunHandler(tornado.web.RequestHandler):
    async def post(self, command):
        timeout = config.get('timeout', 30)

        if command == 'read':
            cmd, stdin = [bin_path('read_personalized')] + nfc_args(), None
        elif command == 'prepersonalize':
            cmd, stdin = [bin_path('pre_personalize')] + nfc_args(), None
        elif command == 'personalize':
            mid = self.get_argument('mid', '').strip()
            if not mid:
                self.write({'error': 'mid is required', 'ok': False})
                return
            cmd = [bin_path('personalize')] + nfc_args()
            stdin = (mid + '\n').encode()
        else:
            self.set_status(400)
            self.write({'error': 'unknown command', 'ok': False})
            return

        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(executor, run_process, cmd, stdin, timeout)
        self.write(result)


def make_app():
    return tornado.web.Application([
        (r'/', IndexHandler),
        (r'/run/(read|prepersonalize|personalize)', RunHandler),
    ])


if __name__ == '__main__':
    cfg_path = sys.argv[1] if len(sys.argv) > 1 else 'config.yml'
    with open(cfg_path) as f:
        config = yaml.safe_load(f)

    port = config.get('listen_port', 8080)
    make_app().listen(port)
    print(f'Listening on http://0.0.0.0:{port}')
    tornado.ioloop.IOLoop.current().start()
