# Docker Setup Guide for MT5 API Bridge

## Why Docker?

The Docker solution from `mt5-works/MetaTrader5-Docker` is **proven to work**. It handles all the complexity of:
- Installing Wine
- Installing MT5 Terminal
- Installing Windows Python in Wine
- Installing Windows MetaTrader5 library
- Setting up the RPyC server
- Managing all the dependencies

## Quick Setup

Run this on your VPS:

```bash
cd /opt/mt5-api-bridge
git pull
chmod +x SETUP_DOCKER_MT5.sh
./SETUP_DOCKER_MT5.sh
```

This script will:
1. Install Docker (if needed)
2. Pull and run the MT5 Docker container
3. Wait for MT5 to be ready
4. Test the connection
5. Update your .env file with correct settings

## What Gets Installed

The Docker container (`gmag11/metatrader5_vnc`) includes:
- MT5 Terminal running in Wine
- Windows Python 3.9.13 in Wine
- Windows MetaTrader5 library (5.0.36)
- RPyC server on port 8001
- VNC access on port 3000

## Ports

- **8001**: RPyC server (for Python API access)
- **3000**: VNC web interface (for MT5 Terminal GUI)

## Environment Variables

After running the setup script, your `.env` file will have:
```
MT5_RPC_HOST=localhost
MT5_RPC_PORT=8001
```

## Accessing MT5 Terminal GUI

Open in your browser:
```
http://147.182.206.223:3000
```

Or use your VPS IP:
```
http://<your-vps-ip>:3000
```

You can use this to:
- Log in to MT5 Terminal manually (if needed)
- View MT5 Terminal interface
- Configure MT5 settings

## Testing the Connection

After setup, test with:

```bash
cd /opt/mt5-api-bridge
source venv/bin/activate
python3 <<EOF
from mt5linux import MetaTrader5
mt5 = MetaTrader5(host='localhost', port=8001)
if mt5.initialize():
    print("✅ MT5 is working!")
    account = mt5.account_info()
    if account:
        print(f"Account: {account.login}")
        print(f"Server: {account.server}")
        print(f"Balance: {account.balance}")
else:
    print("❌ MT5 not ready yet")
EOF
```

## Docker Commands

```bash
# View logs
docker logs mt5

# View logs (follow)
docker logs -f mt5

# Stop container
docker stop mt5

# Start container
docker start mt5

# Restart container
docker restart mt5

# Remove container (stops and deletes)
docker stop mt5 && docker rm mt5

# View container status
docker ps | grep mt5
```

## Troubleshooting

### Container won't start
```bash
docker logs mt5
```
Check the logs for errors.

### RPyC connection fails
1. Wait 2-3 minutes after first start (MT5 needs time to install)
2. Check if container is running: `docker ps | grep mt5`
3. Check RPyC port: `netstat -tlnp | grep 8001`
4. View logs: `docker logs mt5`

### MT5 Terminal not accessible via VNC
1. Check if port 3000 is open: `netstat -tlnp | grep 3000`
2. Check firewall: `ufw status`
3. Try accessing from VPS: `curl http://localhost:3000`

### Need to reinstall
```bash
docker stop mt5
docker rm mt5
docker volume rm mt5-config
./SETUP_DOCKER_MT5.sh
```

## Next Steps

After Docker setup is complete:

1. **Log in to MT5 Terminal** (via VNC if needed):
   - Open: http://147.182.206.223:3000
   - Log in with your credentials:
     - Server: MetaQuotes-Demo
     - Login: 5042856355
     - Password: V!QzRxQ7

2. **Complete API setup**:
   ```bash
   ./TEST_AND_SETUP.sh
   ```
   This will:
   - Start the FastAPI service
   - Configure Nginx
   - Set up SSL

3. **Test the API**:
   ```bash
   curl http://localhost:8001/health
   ```

## Advantages of Docker Solution

✅ **Proven to work** - You've already tested it on VNC  
✅ **Self-contained** - All dependencies in one container  
✅ **Easy to manage** - Start/stop/restart with simple commands  
✅ **Isolated** - Doesn't interfere with system packages  
✅ **Automatic updates** - MT5 Terminal updates itself  
✅ **VNC access** - Can access GUI when needed  

## Comparison with Manual Setup

| Feature | Docker | Manual Setup |
|---------|--------|--------------|
| Setup time | 5-10 min | Hours of troubleshooting |
| Reliability | ✅ Proven | ⚠️ Many issues |
| Maintenance | ✅ Easy | ❌ Complex |
| VNC access | ✅ Built-in | ❌ Need to set up |
| Updates | ✅ Automatic | ❌ Manual |

## Notes

- First run takes 5-10 minutes (downloads and installs everything)
- Container size is ~4GB (includes Wine, Python, MT5, etc.)
- MT5 Terminal auto-updates inside the container
- All MT5 data persists in Docker volume `mt5-config`

