#!/usr/bin/env python3

from argparse import ArgumentParser, REMAINDER
import base64
import ctypes
import errno
import hashlib
import io
import os
import re
import signal
import shutil
import socket
import subprocess
import tempfile
import sys
import threading
import time

NOFEAR_DIR = '/usr/local/share/nofear/'
SHARED_DIR = '/shared'


class NoFearError(Exception):
    pass


class InitScript:
    def __init__(self, gui, xpra_port, shared_folder, *args):
        self.args = [ a for a in args ]
        self.path = ''
        self.shared_folder = shared_folder

        if gui:
            # prefix command by the gui script path, which requires host tcp
            # port as first argument
            self.args.insert(0, '{}'.format(xpra_port))
            self.args.insert(0, os.path.join(NOFEAR_DIR, 'gui.sh'))

    def write(self, profile, path):
        content_fmt  = '#!/bin/bash\n'
        if self.shared_folder:
            content_fmt += 'export NOFEAR_SHARED="{}"\n'.format(self.shared_folder)
        content_fmt += 'exec {}/base.sh {} {}\n'
        content = content_fmt.format(NOFEAR_DIR, profile, ' '.join(self.args))

        dir = os.path.join(path, 'virt/')

        try:
            fd, self.path = tempfile.mkstemp(prefix='sandbox-', dir=dir)
        except OSError as e:
            if e.errno == errno.ENOENT:
                print('[-] profile "{}" doesn\'t exist'.format(profile), file=sys.stderr)
                sys.exit(1)
            else:
                raise

        os.fchmod(fd, 0o755)
        os.write(fd, content.encode('utf-8'))
        os.close(fd)

    def get_tmpname(self):
        script_path = os.path.basename(self.path)
        return re.sub('.*-', '', script_path)

    def delete(self):
        os.unlink(self.path)


class Profile:
    def __init__(self, name):
        self._check_profile_name(name)
        self.name = name
        self.path = os.path.join(os.path.expanduser('~'), '.lkvm/', self.name)

    @classmethod
    def list_available(cls):
        path = os.path.join(os.path.expanduser('~'), '.lkvm/')
        for filename in os.listdir(path):
            try:
                cls._check_profile_name(filename)
            except NoFearError:
                continue
            fullpath = os.path.join(path, filename)
            if os.path.isdir(fullpath) and not os.path.islink(fullpath):
                print(filename)

    @staticmethod
    def _check_profile_name(name):
        # avoid path traversal attacks
        if not re.match('^[a-zA-Z0-9][a-zA-Z0-9-_.]*$', name):
            raise NoFearError('invalid profile "{}"'.format(name))

    def create_profile(self):
        '''
        Call "lkvm setup profile name" to create and initialize ~/.lkvm/profile/
        directory.
        '''

        args = [ 'lkvm-nofear', 'setup', self.name ]
        p = subprocess.Popen(args, universal_newlines=True, stdout=subprocess.PIPE)
        stdout, stderr = p.communicate()
        if p.returncode != 0:
            if stdout:
                sys.stdout.write(stdout)
            if stderr:
                sys.stderr.write(stderr)
            sys.exit(1)
        else:
            print('[+] profile "{}" created successfully'.format(self.name), file=sys.stderr)

    def delete_profile(self):
        '''
        rm -rf ~/.lkvm/profile/
        '''

        shutil.rmtree(self.path)
        print('[+] profile "{}" deleted successfully'.format(self.name), file=sys.stderr)


    def create_init_script(self, gui, xpra_port, shared_folder, *args):
        script = InitScript(gui, xpra_port, shared_folder, *args)
        script.write(self.name, self.path)
        return script


def set_pdeath(sig):
    '''Set the parent death signal of the calling process.'''

    PR_SET_PDEATHSIG = 1
    libc = ctypes.cdll.LoadLibrary('libc.so.6')
    libc.prctl(PR_SET_PDEATHSIG, sig)


def bind_tcp(port=0):
    '''Create and bind a TCP socket to a random free port.'''

    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(('0.0.0.0', port))
    s.listen(1)

    _, port = s.getsockname()
    return (s, port)


class XpraTCPProxy(threading.Thread):
    def __init__(self, sock1, sock2):
        threading.Thread.__init__(self)
        self.sock1 = sock1
        self.sock2 = sock2

    def run(self):
        while True:
            data = self.sock1.recv(8192)
            if not data:
                break
            self.sock2.sendall(data)


def run_xpra(xpra_socket, xpra_port, with_sound=False):
    '''Proxify connection between guest and host xpra.'''

    # wait for incoming connection from guest xpra
    s, _ = xpra_socket.accept()
    print('[*] nofear: got connection on {}'.format(xpra_port), file=sys.stderr)
    xpra_socket.close()

    # bind a random tcp port and connect host xpra to it
    tcp, port = bind_tcp()
    pid = os.fork()
    if pid == 0:
        set_pdeath(signal.SIGTERM)
        tcp.close()
        s.close()
        print('[*] nofear: executing xpra', file=sys.stderr)
        devnull = open('/dev/null', 'w')
        os.dup2(devnull.fileno(), sys.stderr.fileno())

        xpra_cmd = [ 'xpra', 'attach', 'tcp:127.0.0.1:{}'.format(port) ]
        if not with_sound:
            xpra_cmd.insert(2, '--speaker=disabled')
        else:
            xpra_cmd.insert(2, '--speaker=on')

        # enforce some options from nofear's xpra configuration
        os.putenv('XPRA_USER_CONF_DIR', NOFEAR_DIR)

        os.execvp(xpra_cmd[0], xpra_cmd)
        sys.exit(1)

    c, _ = tcp.accept()
    print('[*] nofear: got connection on %d' % port, file=sys.stderr)
    tcp.close()

    # proxify connection
    thread1 = XpraTCPProxy(c, s)
    thread2 = XpraTCPProxy(s, c)

    thread1.start()
    thread2.start()

    thread1.join()
    thread2.join()


if __name__ == '__main__':
    parser = ArgumentParser(prog='{}'.format(sys.argv[0]), description="Execute a new virtualized process.")
    parser.add_argument('-d', '--delete-profile', action='store', default=None, help="Delete an existing profile")
    parser.add_argument('-f', '--shared-folder', action='store', default=None, help="Share a folder between host and guest into {}".format(SHARED_DIR))
    parser.add_argument('-g', '--gui', action='store_true', default=False, help="Enable graphical interface")
    parser.add_argument('-l', '--list-profiles', action='store_true', default=False, help="List available profiles")
    parser.add_argument('-n', '--new-profile', action='store', default=None, help="Create a new profile")
    parser.add_argument('-p', '--profile', action='store', default='default', help="Specify profile name")
    parser.add_argument('-s', '--sound', action='store_true', default=False, help="Enable sound")
    parser.add_argument('-t', '--temporary', action='store_true', default=False, help="Use a temporary profile")
    parser.add_argument('target', nargs=REMAINDER)

    args = parser.parse_args()

    if args.temporary:
        if args.delete_profile:
            print("[-] --temporary and --delete arguments are exclusive", file=sys.stderr)
            sys.exit(1)

        if args.new_profile:
            print("[-] --temporary and --new-profile arguments are exclusive", file=sys.stderr)
            sys.exit(1)

        if args.profile != 'default':
            print("[-] --temporary and --profile arguments are exclusive", file=sys.stderr)
            sys.exit(1)

        timestamp = '{}'.format(time.time()).encode('utf-8')
        args.profile = hashlib.sha256(timestamp).hexdigest()

    if args.list_profiles:
        Profile.list_available()
        sys.exit(0)

    if args.delete_profile:
        profile = Profile(args.delete_profile)
        profile.delete_profile()
        sys.exit(0)

    if args.new_profile:
        profile = Profile(args.new_profile)
        profile.create_profile()
        sys.exit(0)

    if len(args.target) == 0 and not args.gui:
        args.target = [ 'bash', '-i' ]

    profile = Profile(args.profile)

    # create profile if it doesn't exist
    if not os.path.exists(profile.path):
        profile.create_profile()

    if args.gui:
        xpra_socket, xpra_port = bind_tcp()
    else:
        xpra_port = 65536

    if args.shared_folder:
        shared_folder = SHARED_DIR
    else:
        shared_folder = None

    script = profile.create_init_script(args.gui, xpra_port, shared_folder, *args.target)

    lkvm_cmd = [
        'lkvm-nofear', 'run',
	'--kernel', os.path.join(NOFEAR_DIR, 'bzImage'),
	'--mem', '2048',
	'--params', 'quiet sandbox={}'.format(script.get_tmpname()),
	'--disk', profile.name,
        #'--network', 'mode=user,guest_mac=02:15:15:15:15:15',
        '--network', 'mode=tap,guest_mac=02:15:15:15:13:37',
    ]

    if shared_folder:
        lkvm_cmd += [ '--9p', args.shared_folder + ',nofear-shared' ]

    # launch gui if specified
    if args.gui:
        pid = os.fork()
        if pid == 0:
            set_pdeath(signal.SIGTERM)
            run_xpra(xpra_socket, xpra_port, with_sound=args.sound)
            sys.exit(0)
        else:
            xpra_socket.close()

    # run lkvm
    returncode = subprocess.call(lkvm_cmd)

    script.delete()

    if args.temporary:
        profile.delete_profile()

    sys.exit(returncode)
