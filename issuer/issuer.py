import asyncio
import json
import os
import sys

import tornado.ioloop
import tornado.web
import yaml

config = {}
active_proc = None


def resource_path(relative):
    base = getattr(sys, '_MEIPASS', os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base, relative)


def bin_path(name):
    return os.path.join(config.get('bin_dir', '.'), name)


def nfc_args():
    device = config.get('nfc_device', '')
    return [device] if device else []


def clean_env():
    env = os.environ.copy()
    env.pop('LD_LIBRARY_PATH', None)
    return env


async def kill_proc(proc):
    if proc is None or proc.returncode is not None:
        return
    proc.terminate()
    try:
        await asyncio.wait_for(proc.wait(), timeout=3)
    except asyncio.TimeoutError:
        proc.kill()


class IndexHandler(tornado.web.RequestHandler):
    def get(self):
        with open(resource_path('static/index.html'), 'rb') as f:
            self.write(f.read())


class StreamHandler(tornado.web.RequestHandler):
    async def get(self, command):
        global active_proc

        await kill_proc(active_proc)
        active_proc = None

        if command == 'read':
            cmd = [bin_path('read_personalized')] + nfc_args()
            stdin_data = None
        elif command == 'prepersonalize':
            cmd = [bin_path('pre_personalize')] + nfc_args()
            stdin_data = None
        elif command == 'personalize':
            mid = self.get_argument('mid', '').strip()
            if not mid:
                self.set_status(400)
                self.write('mid required')
                return
            cmd = [bin_path('personalize')] + nfc_args()
            stdin_data = (mid + '\n').encode()
        else:
            self.set_status(400)
            return

        self.set_header('Content-Type', 'text/event-stream')
        self.set_header('Cache-Control', 'no-cache')
        self.set_header('X-Accel-Buffering', 'no')

        print(f'[issuer] starting: {cmd}', flush=True)

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdin=asyncio.subprocess.PIPE if stdin_data else asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            env=clean_env(),
        )
        active_proc = proc

        if stdin_data:
            proc.stdin.write(stdin_data)
            await proc.stdin.drain()
            proc.stdin.close()

        try:
            async for raw in proc.stdout:
                line = raw.decode(errors='replace').rstrip()
                self.write(f'data: {json.dumps({"line": line})}\n\n')
                await self.flush()
        except Exception as e:
            print(f'[issuer] stream error: {e}', flush=True)
        finally:
            await proc.wait()
            print(f'[issuer] exited: {proc.returncode}', flush=True)
            if active_proc is proc:
                active_proc = None

        try:
            self.write(f'data: {json.dumps({"done": True})}\n\n')
            await self.flush()
        except Exception:
            pass

    def on_connection_close(self):
        global active_proc
        if active_proc and active_proc.returncode is None:
            print('[issuer] client disconnected, stopping process', flush=True)
            active_proc.terminate()
            active_proc = None


class StopHandler(tornado.web.RequestHandler):
    async def post(self):
        global active_proc
        proc = active_proc
        active_proc = None
        await kill_proc(proc)
        self.write({'ok': True})


def make_app():
    return tornado.web.Application([
        (r'/', IndexHandler),
        (r'/stream/(read|prepersonalize|personalize)', StreamHandler),
        (r'/stop', StopHandler),
    ])


if __name__ == '__main__':
    cfg_path = sys.argv[1] if len(sys.argv) > 1 else 'config.yml'
    with open(cfg_path) as f:
        config = yaml.safe_load(f)

    port = config.get('listen_port', 8080)
    make_app().listen(port)
    print(f'Listening on http://0.0.0.0:{port}')
    tornado.ioloop.IOLoop.current().start()
