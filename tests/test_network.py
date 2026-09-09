"""Integration checks against a real Burns WebSocket server (pip install websockets)."""
import asyncio
import json
import os
import subprocess
import uuid
from pathlib import Path
import websockets

ROOT = Path(__file__).resolve().parents[1]
PORT = 19080

async def receive(ws, kind):
    for _ in range(40):
        msg = json.loads(await asyncio.wait_for(ws.recv(), 5))
        if msg.get('type') == kind:
            return msg
    raise AssertionError(f'No {kind} response')

async def send(ws, **message):
    await ws.send(json.dumps(message))

async def connect():
    return await websockets.connect(f'ws://127.0.0.1:{PORT}')

async def main():
    log_path = ROOT / 'build/network-test.log'
    log_path.parent.mkdir(exist_ok=True)
    store_path = ROOT / 'build' / f'network-test-{uuid.uuid4().hex}.cfg'
    command = [os.environ.get('GODOT', 'godot'), '--headless', '--path', str(ROOT), '--', '--server', f'--port={PORT}', f'--server-store={store_path}']
    with log_path.open('w') as log:
        server = subprocess.Popen(command, stdout=log, stderr=log)
        clients = []
        try:
            for _ in range(60):
                try:
                    host = await connect()
                    break
                except OSError:
                    await asyncio.sleep(.1)
            else:
                raise AssertionError('Server did not start')
            clients.append(host)
            await send(host, type='hello', name='Host', room='')
            welcome = await receive(host, 'welcome')
            code = welcome['room']
            await receive(host, 'state')
            guest = await connect(); clients.append(guest)
            await send(guest, type='hello', name='Guest', room=code)
            guest_key = await receive(guest, 'welcome')
            await receive(guest, 'state'); await receive(host, 'state')
            third = await connect(); clients.append(third)
            await send(third, type='hello', name='Third', room=code)
            await receive(third, 'welcome'); await receive(third, 'state')
            await receive(guest, 'state'); await receive(host, 'state')
            await send(guest, type='start')
            assert 'host' in (await receive(guest, 'error'))['message']
            await send(host, type='start')
            state = (await receive(host, 'state'))['game']
            await receive(guest, 'state'); await receive(third, 'state')
            assert len(state['players']) == 3
            assert 'missed' not in state and 'interrupts' not in state
            for player in state['players']:
                assert not {'play', 'reserve', 'discard'} & player.keys(), 'Hidden pile leaked'
                assert player['held'] == -1
            await send(guest, type='action', revision=state['revision'], action={'type':'draw', 'seat':0})
            assert 'turn' in (await receive(guest, 'error'))['message']
            await send(host, type='action', revision=state['revision'], action={'type':'draw'})
            state = (await receive(host, 'state'))['game']
            await receive(guest, 'state'); await receive(third, 'state')
            assert state['players'][0]['held'] >= 0
            await send(host, type='action', revision=state['revision']-1, action={'type':'end'})
            assert 'changed' in (await receive(host, 'error'))['message']
            await receive(host, 'state')
            await send(host, type='action', revision=state['revision'], action={'type':'end'})
            state = (await receive(host, 'state'))['game']
            await receive(guest, 'state'); await receive(third, 'state')
            assert state['phase'] == 'review'
            # Same-revision competing claims: exactly one is accepted by the server.
            await asyncio.gather(send(guest, type='action', revision=state['revision'], action={'type':'burn'}), send(third, type='action', revision=state['revision'], action={'type':'burn'}))
            state = (await receive(host, 'state'))['game']
            assert state['phase'] == 'penalty'
            assert state['burn_serial'] == 1, 'Only one competing claim should resolve'
            assert state['burnt'] == 0 if state['burn_correct'] else state['burnt'] in (1, 2)
            # Disconnect and resume the guest's exact seat; a random token is rejected.
            await guest.close()
            disconnected = await receive(host, 'state')
            while disconnected['seats'][1]['connected']:
                disconnected = await receive(host, 'state')
            attacker = await connect(); clients.append(attacker)
            await send(attacker, type='hello', room=code, token='invalid')
            assert 'invalid' in (await receive(attacker, 'error'))['message']
            guest2 = await connect(); clients.append(guest2)
            await send(guest2, type='hello', room=code, token=guest_key['token'])
            restored = await receive(guest2, 'welcome')
            assert restored['seat'] == 1
            restored_state = await receive(guest2, 'state')
            assert restored_state['game']['revision'] == state['revision']
            assert restored_state['game']['phase'] == 'penalty'
            # Restart the process and reclaim the host seat from durable room storage.
            for ws in clients:
                await ws.close()
            clients.clear()
            server.terminate(); server.wait(timeout=5)
            server = subprocess.Popen(command, stdout=log, stderr=log)
            for _ in range(60):
                try:
                    resumed_host = await connect()
                    break
                except OSError:
                    await asyncio.sleep(.1)
            else:
                raise AssertionError('Restarted server did not start')
            clients.append(resumed_host)
            await send(resumed_host, type='hello', room=code, token=welcome['token'])
            resumed_key = await receive(resumed_host, 'welcome')
            assert resumed_key['seat'] == 0
            recovered = await receive(resumed_host, 'state')
            assert recovered['game']['revision'] == state['revision']
            assert recovered['game']['phase'] == 'penalty'
            print('PASS: real server rooms, host authority, hidden-card redaction, turn ownership, revision rejection, competing Burns, reconnect tokens, durable restart')
        finally:
            for ws in clients:
                await ws.close()
            server.terminate()
            server.wait(timeout=5)
            store_path.unlink(missing_ok=True)
    output = log_path.read_text()
    assert 'SCRIPT ERROR' not in output and 'ERROR:' not in output, output

asyncio.run(main())
