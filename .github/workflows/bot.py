import discord
from discord.ext import commands
import asyncio
import subprocess
import json
from datetime import datetime, timedelta
import shlex
import logging
import shutil
import os
from typing import Optional, List, Dict, Any
import threading
import time
import sqlite3
import random
import requests
import string
import secrets
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()
# ─── Container runtime auto-detection ────────────────────────────────────────
def detect_lxc_binary() -> str:
    """
    Detect the available container CLI in priority order:
      1. incus   (modern Incus project)
      2. lxc     (LXD / canonical LXC)
      3. lxc-fs  (older LXC-FS setups)
    Falls back to 'lxc' if nothing is found (preserves old behaviour).
    """
    for candidate in ("incus", "lxc", "lxc-fs"):
        if shutil.which(candidate):
            return candidate
    return "lxc"   # safe default — will error at runtime if truly absent

LXC_CMD: str = detect_lxc_binary()
# Log the detected binary once at startup (shutil is already imported above)
import logging as _logging_tmp
_logging_tmp.getLogger("root").info(f"[Runtime] Container CLI detected: '{LXC_CMD}'")
del _logging_tmp
# ─────────────────────────────────────────────────────────────────────────────

# Load environment variables
DISCORD_TOKEN = os.getenv('DISCORD_TOKEN')
BOT_NAME = os.getenv('BOT_NAME', 'PapiaGamerz VMS')
PREFIX = os.getenv('PREFIX', '!')
YOUR_SERVER_IP = os.getenv('YOUR_SERVER_IP')
MAIN_ADMIN_ID = int(os.getenv('MAIN_ADMIN_ID', '1210291131301101618'))
VPS_USER_ROLE_ID = int(os.getenv('VPS_USER_ROLE_ID', '1210291131301101618'))
DEFAULT_STORAGE_POOL = os.getenv('DEFAULT_STORAGE_POOL', 'default')
HOST_MOTD = os.getenv('HOST_MOTD', '')
BOT_VERSION = os.getenv('BOT_VERSION', '8.0-PRO')
BOT_DEVELOPER = os.getenv('BOT_DEVELOPER', 'PapiaGamerz')
BOT_THUMBNAIL_URL = os.getenv('BOT_THUMBNAIL_URL', 'https://i.imgur.com/Tv3clt0.jpeg')
BOT_ICON_URL = os.getenv('BOT_ICON_URL', 'https://i.imgur.com/Tv3clt0.jpeg')

# VPS Expiration Settings
DEFAULT_VPS_EXPIRATION_DAYS = int(os.getenv('DEFAULT_VPS_EXPIRATION_DAYS', '30'))
EXPIRATION_WARNING_DAYS = int(os.getenv('EXPIRATION_WARNING_DAYS', '1'))

# !deploy command — members with DEPLOY_ROLE_ID get free VPS instantly
# Set these in your .env file:
#   DEPLOY_ROLE_ID=<discord_role_id>   (the member role that can use !deploy)
#   DEPLOY_RAM=16                       (GB of RAM per deployed VPS)
#   DEPLOY_CPU=3                        (CPU cores per deployed VPS)
#   DEPLOY_DISK=80                      (GB disk per deployed VPS)
#   VPS_DEPLOY_LIMIT=2                  (max VPS per user via !deploy — users cannot create more than this)
#   DEPLOY_SLOT=2                       (total global VPS slot cap across ALL users, 0 = unlimited)
DEPLOY_ROLE_ID = int(os.getenv('DEPLOY_ROLE_ID', '0'))
DEPLOY_RAM     = int(os.getenv('DEPLOY_RAM',  '16'))
DEPLOY_CPU     = int(os.getenv('DEPLOY_CPU',  '3'))
DEPLOY_DISK    = int(os.getenv('DEPLOY_DISK', '80'))
# VPS_DEPLOY_LIMIT = max VPS a single user can create via !deploy
# Supports both VPS_DEPLOY_LIMIT (new) and DEPLOY_LIMIT (old) — VPS_DEPLOY_LIMIT takes priority
DEPLOY_LIMIT   = int(os.getenv('VPS_DEPLOY_LIMIT', os.getenv('DEPLOY_LIMIT', '2')))
DEPLOY_SLOT    = int(os.getenv('DEPLOY_SLOT', '0'))

# SSH Configuration
SSH_FIX_SCRIPT = """#!/bin/bash
cat > /etc/ssh/sshd_config << 'SSHEOF'
Port 22
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::
PasswordAuthentication yes
PubkeyAuthentication yes
PermitRootLogin yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
MaxAuthTries 6
MaxSessions 10
SyslogFacility AUTH
LogLevel INFO
X11Forwarding yes
X11DisplayOffset 10
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
PermitUserEnvironment no
Subsystem sftp /usr/lib/openssh/sftp-server
SSHEOF
systemctl restart ssh 2>/dev/null || service ssh restart 2>/dev/null || /etc/init.d/ssh restart 2>/dev/null || true
"""

# OS Options for VPS Creation and Reinstall
OS_OPTIONS = [
    {"label": "Ubuntu 20.04 LTS", "value": "ubuntu:20.04"},
    {"label": "Ubuntu 22.04 LTS", "value": "ubuntu:22.04"},
    {"label": "Ubuntu 24.04 LTS", "value": "ubuntu:24.04"},
    {"label": "Debian 10 (Buster)", "value": "images:debian/10"},
    {"label": "Debian 11 (Bullseye)", "value": "images:debian/11"},
    {"label": "Debian 12 (Bookworm)", "value": "images:debian/12"},
    {"label": "Debian 13 (Trixie)", "value": "images:debian/13"},
]

# Configure logging to file and console
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('bot.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(f'{BOT_NAME.lower()}_vps_bot')

# Database setup
def get_db():
    conn = sqlite3.connect('vps.db')
    conn.execute("PRAGMA journal_mode=WAL")
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    cur = conn.cursor()
    cur.execute('''CREATE TABLE IF NOT EXISTS admins (
        user_id TEXT PRIMARY KEY
    )''')
    cur.execute('INSERT OR IGNORE INTO admins (user_id) VALUES (?)', (str(MAIN_ADMIN_ID),))
    cur.execute('''CREATE TABLE IF NOT EXISTS nodes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        location TEXT,
        total_vps INTEGER,
        tags TEXT DEFAULT '[]',
        api_key TEXT,
        url TEXT,
        is_local INTEGER DEFAULT 0
    )''')
    # Add local node if not exists
    cur.execute('SELECT COUNT(*) FROM nodes WHERE is_local = 1')
    if cur.fetchone()[0] == 0:
        cur.execute('INSERT INTO nodes (name, location, total_vps, tags, api_key, url, is_local) VALUES (?, ?, ?, ?, ?, ?, ?)',
                    ('Local Node', 'Local', 100, '[]', None, None, 1))  # Default capacity 100
    cur.execute('''CREATE TABLE IF NOT EXISTS vps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        node_id INTEGER NOT NULL DEFAULT 1,
        container_name TEXT UNIQUE NOT NULL,
        ram TEXT NOT NULL,
        cpu TEXT NOT NULL,
        storage TEXT NOT NULL,
        config TEXT NOT NULL,
        os_version TEXT DEFAULT 'ubuntu:22.04',
        status TEXT DEFAULT 'stopped',
        suspended INTEGER DEFAULT 0,
        whitelisted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        shared_with TEXT DEFAULT '[]',
        suspension_history TEXT DEFAULT '[]',
        expiration_date TEXT DEFAULT NULL,
        root_password TEXT DEFAULT NULL
    )''')
    # Migrations
    cur.execute('PRAGMA table_info(vps)')
    info = cur.fetchall()
    columns = [col[1] for col in info]
    if 'os_version' not in columns:
        cur.execute("ALTER TABLE vps ADD COLUMN os_version TEXT DEFAULT 'ubuntu:22.04'")
    if 'node_id' not in columns:
        cur.execute("ALTER TABLE vps ADD COLUMN node_id INTEGER DEFAULT 1")
    if 'expiration_date' not in columns:
        cur.execute("ALTER TABLE vps ADD COLUMN expiration_date TEXT DEFAULT NULL")
    if 'root_password' not in columns:
        cur.execute("ALTER TABLE vps ADD COLUMN root_password TEXT DEFAULT NULL")
    cur.execute('''CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
    )''')
    settings_init = [
        ('cpu_threshold', '90'),
        ('ram_threshold', '90'),
    ]
    for key, value in settings_init:
        cur.execute('INSERT OR IGNORE INTO settings (key, value) VALUES (?, ?)', (key, value))
    cur.execute('''CREATE TABLE IF NOT EXISTS port_allocations (
        user_id TEXT PRIMARY KEY,
        allocated_ports INTEGER DEFAULT 0
    )''')
    cur.execute('''CREATE TABLE IF NOT EXISTS port_forwards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        vps_container TEXT NOT NULL,
        vps_port INTEGER NOT NULL,
        host_port INTEGER NOT NULL,
        created_at TEXT NOT NULL
    )''')
    conn.commit()
    conn.close()

def get_setting(key: str, default: Any = None):
    conn = get_db()
    cur = conn.cursor()
    cur.execute('SELECT value FROM settings WHERE key = ?', (key,))
    row = cur.fetchone()
    conn.close()
    return row[0] if row else default

def set_setting(key: str, value: str):
    conn = get_db()
    cur = conn.cursor()
    cur.execute('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)', (key, value))
    conn.commit()
    conn.close()

def get_nodes() -> List[Dict]:
    conn = get_db()
    cur = conn.cursor()
    cur.execute('SELECT * FROM nodes')
    rows = cur.fetchall()
    conn.close()
    nodes = [dict(row) for row in rows]
    for node in nodes:
        node['tags'] = json.loads(node['tags'])
        # Ensure is_local is properly converted
        node['is_local'] = int(node.get('is_local', 1)) == 1
    return nodes

def get_node(node_id: int) -> Optional[Dict]:
    conn = get_db()
    cur = conn.cursor()
    cur.execute('SELECT * FROM nodes WHERE id = ?', (node_id,))
    row = cur.fetchone()
    conn.close()
    if row:
        node = dict(row)
        node['tags'] = json.loads(node['tags'])
        # Ensure is_local is properly converted
        node['is_local'] = int(node.get('is_local', 1)) == 1
        return node
    return None

def get_vps_by_id(vps_id: int) -> Optional[Dict]:
    """Get VPS info by global VPS ID"""
    conn = get_db()
    cur = conn.cursor()
    cur.execute('SELECT * FROM vps WHERE id = ?', (vps_id,))
    row = cur.fetchone()
    conn.close()
    if row:
        vps = dict(row)
        vps['shared_with'] = json.loads(vps.get('shared_with', '[]'))
        vps['suspension_history'] = json.loads(vps.get('suspension_history', '[]'))
        vps['suspended'] = bool(vps.get('suspended', 0))
        vps['whitelisted'] = bool(vps.get('whitelisted', 0))
        vps['os_version'] = vps.get('os_version', 'ubuntu:22.04')
        return vps
    return None

def get_current_vps_count(node_id: int) -> int:
    conn = get_db()
    cur = conn.cursor()
    cur.execute('SELECT COUNT(*) FROM vps WHERE node_id = ?', (node_id,))
    count = cur.fetchone()[0]
    conn.close()
    return count

def get_vps_data() -> Dict[str, List[Dict[str, Any]]]:
    conn = get_db()
    cur = conn.cursor()
    cur.execute('SELECT * FROM vps')
    rows = cur.fetchall()
    conn.close()
    data = {}
    for row in rows:
        user_id = row['user_id']
        if user_id not in data:
            data[user_id] = []
        vps = dict(row)
        vps['shared_with'] = json.loads(vps['shared_with'])
        vps['suspension_history'] = json.loads(vps['suspension_history'])
        vps['suspended'] = bool(vps['suspended'])
        vps['whitelisted'] = bool(vps['whitelisted'])
        vps['os_version'] = vps.get('os_version', 'ubuntu:22.04')
        data[user_id].append(vps)
    return data

def get_admins() -> List[str]:
    conn = get_db()
    cur = conn.cursor()
    cur.execute('SELECT user_id FROM admins')
    rows = cur.fetchall()
    conn.close()
    return [row['user_id'] for row in rows]

def save_vps_data():
    """Persist in-memory vps_data to SQLite via safe UPSERT.
    Never deletes rows — deletion is handled explicitly by delete commands.
    This prevents data loss on restart/reconnect race conditions.
    """
    if not vps_data:
        return  # Nothing to save; don't wipe the DB
    conn = get_db()
    cur = conn.cursor()
    for user_id, vps_list in vps_data.items():
        for vps in vps_list:
            shared_json = json.dumps(vps.get('shared_with', []))
            history_json = json.dumps(vps.get('suspension_history', []))
            suspended_int = 1 if vps.get('suspended') else 0
            whitelisted_int = 1 if vps.get('whitelisted', False) else 0
            os_ver = vps.get('os_version', 'ubuntu:22.04')
            created_at = vps.get('created_at', datetime.now().isoformat())
            node_id = vps.get('node_id', 1)
            expiration_date = vps.get('expiration_date', None)
            root_password = vps.get('root_password', None)
            status = vps.get('status', 'stopped')
            if 'id' not in vps or vps['id'] is None:
                cur.execute(
                    '''INSERT OR IGNORE INTO vps
                       (user_id, node_id, container_name, ram, cpu, storage, config,
                        os_version, status, suspended, whitelisted, created_at,
                        shared_with, suspension_history, expiration_date, root_password)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
                    (user_id, node_id, vps['container_name'], vps['ram'], vps['cpu'],
                     vps['storage'], vps['config'], os_ver, status,
                     suspended_int, whitelisted_int, created_at,
                     shared_json, history_json, expiration_date, root_password))
                vps['id'] = cur.lastrowid
            else:
                cur.execute(
                    '''UPDATE vps SET user_id=?, node_id=?, container_name=?, ram=?, cpu=?,
                       storage=?, config=?, os_version=?, status=?, suspended=?,
                       whitelisted=?, shared_with=?, suspension_history=?,
                       expiration_date=?, root_password=?
                       WHERE id=?''',
                    (user_id, node_id, vps['container_name'], vps['ram'], vps['cpu'],
                     vps['storage'], vps['config'], os_ver, status,
                     suspended_int, whitelisted_int, shared_json, history_json,
                     expiration_date, root_password, vps['id']))
    conn.commit()
    conn.close()

def save_admin_data():
    conn = get_db()
    cur = conn.cursor()
    cur.execute('DELETE FROM admins')
    for admin_id in admin_data['admins']:
        cur.execute('INSERT INTO admins (user_id) VALUES (?)', (admin_id,))
    conn.commit()
    conn.close()

# Port forwarding functions
def get_user_allocation(user_id: str) -> int:
    conn = get_db()
    cur = conn.cursor()
    cur.execute('SELECT allocated_ports FROM port_allocations WHERE user_id = ?', (user_id,))
    row = cur.fetchone()
    conn.close()
    return row[0] if row else 0

def get_user_used_ports(user_id: str) -> int:
    conn = get_db()
    cur = conn.cursor()
    cur.execute('SELECT COUNT(*) FROM port_forwards WHERE user_id = ?', (user_id,))
    row = cur.fetchone()
    conn.close()
    return row[0]

def allocate_ports(user_id: str, amount: int):
    conn = get_db()
    cur = conn.cursor()
    cur.execute('INSERT OR REPLACE INTO port_allocations (user_id, allocated_ports) VALUES (?, COALESCE((SELECT allocated_ports FROM port_allocations WHERE user_id = ?), 0) + ?)', (user_id, user_id, amount))
    conn.commit()
    conn.close()

def deallocate_ports(user_id: str, amount: int):
    conn = get_db()
    cur = conn.cursor()
    cur.execute('UPDATE port_allocations SET allocated_ports = GREATEST(0, allocated_ports - ?) WHERE user_id = ?', (amount, user_id))
    conn.commit()
    conn.close()

def get_available_host_port(node_id: int) -> Optional[int]:
    conn = get_db()
    cur = conn.cursor()
    cur.execute('SELECT host_port FROM port_forwards WHERE vps_container IN (SELECT container_name FROM vps WHERE node_id = ?)', (node_id,))
    used_ports = set(row[0] for row in cur.fetchall())
    conn.close()
    for _ in range(100):
        port = random.randint(20000, 50000)
        if port not in used_ports:
            return port
    return None

async def create_port_forward(user_id: str, container: str, vps_port: int, node_id: int) -> Optional[int]:
    host_port = get_available_host_port(node_id)
    if not host_port:
        return None
    try:
        await execute_lxc(container, f"config device add {container} tcp_proxy_{host_port} proxy listen=tcp:0.0.0.0:{host_port} connect=tcp:127.0.0.1:{vps_port}", node_id=node_id)
        await execute_lxc(container, f"config device add {container} udp_proxy_{host_port} proxy listen=udp:0.0.0.0:{host_port} connect=udp:127.0.0.1:{vps_port}", node_id=node_id)
        conn = get_db()
        cur = conn.cursor()
        cur.execute('INSERT INTO port_forwards (user_id, vps_container, vps_port, host_port, created_at) VALUES (?, ?, ?, ?, ?)',
                    (user_id, container, vps_port, host_port, datetime.now().isoformat()))
        conn.commit()
        conn.close()
        return host_port
    except Exception as e:
        logger.error(f"Failed to create port forward: {e}")
        return None

async def remove_port_forward(forward_id: int, is_admin: bool = False) -> tuple[bool, Optional[str]]:
    conn = get_db()
    cur = conn.cursor()
    cur.execute('SELECT user_id, vps_container, host_port FROM port_forwards WHERE id = ?', (forward_id,))
    row = cur.fetchone()
    if not row:
        conn.close()
        return False, None
    user_id, container, host_port = row
    node_id = find_node_id_for_container(container)
    try:
        await execute_lxc(container, f"config device remove {container} tcp_proxy_{host_port}", node_id=node_id)
        await execute_lxc(container, f"config device remove {container} udp_proxy_{host_port}", node_id=node_id)
        cur.execute('DELETE FROM port_forwards WHERE id = ?', (forward_id,))
        conn.commit()
        conn.close()
        return True, user_id
    except Exception as e:
        logger.error(f"Failed to remove port forward {forward_id}: {e}")
        conn.close()
        return False, None

def get_user_forwards(user_id: str) -> List[Dict]:
    conn = get_db()
    cur = conn.cursor()
    cur.execute('SELECT * FROM port_forwards WHERE user_id = ? ORDER BY created_at DESC', (user_id,))
    rows = cur.fetchall()
    conn.close()
    return [dict(row) for row in rows]

async def recreate_port_forwards(container_name: str) -> int:
    node_id = find_node_id_for_container(container_name)
    readded_count = 0
    conn = get_db()
    cur = conn.cursor()
    cur.execute('SELECT vps_port, host_port FROM port_forwards WHERE vps_container = ?', (container_name,))
    rows = cur.fetchall()
    for row in rows:
        vps_port = row['vps_port']
        host_port = row['host_port']
        try:
            await execute_lxc(container_name, f"config device add {container_name} tcp_proxy_{host_port} proxy listen=tcp:0.0.0.0:{host_port} connect=tcp:127.0.0.1:{vps_port}", node_id=node_id)
            await execute_lxc(container_name, f"config device add {container_name} udp_proxy_{host_port} proxy listen=udp:0.0.0.0:{host_port} connect=udp:127.0.0.1:{vps_port}", node_id=node_id)
            logger.info(f"Re-added port forward {host_port}->{vps_port} for {container_name}")
            readded_count += 1
        except Exception as e:
            logger.error(f"Failed to re-add port forward {host_port}->{vps_port} for {container_name}: {e}")
    conn.close()
    return readded_count

def find_node_id_for_container(container_name: str) -> int:
    conn = get_db()
    cur = conn.cursor()
    cur.execute('SELECT node_id FROM vps WHERE container_name = ?', (container_name,))
    row = cur.fetchone()
    conn.close()
    return row[0] if row else 1  # Default to local

# Initialize database
init_db()

# Load data at startup
vps_data = get_vps_data()
admin_data = {'admins': get_admins()}

# Auto-save flag to prevent constant file writes
_auto_save_pending = False

def mark_for_save():
    """Mark data for auto-save"""
    global _auto_save_pending
    _auto_save_pending = True

async def auto_save_task():
    """Background task to auto-save VPS data periodically"""
    await bot.wait_until_ready()
    while not bot.is_closed():
        try:
            global _auto_save_pending
            if _auto_save_pending:
                save_vps_data()
                _auto_save_pending = False
                logger.debug("Auto-saved VPS data")
        except Exception as e:
            logger.error(f"Error in auto-save task: {e}")
        await asyncio.sleep(2)  # Check every 2 seconds

async def rotating_presence_task():
 
