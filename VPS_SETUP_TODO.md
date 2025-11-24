# VPS Setup & Deployment Todo List

## 📋 Complete Checklist

### Phase 1: VPS Cleanup & Preparation
- [x] Create todo list
- [ ] SSH into VPS (root@147.182.206.223)
- [ ] Identify and list old directories to clean
- [ ] Delete old MT5-related directories
- [ ] Clean up any old Python virtual environments
- [ ] Update system packages

### Phase 2: MT5 Installation
- [ ] Install Python 3 and pip
- [ ] Install mt5linux: `pip install mt5linux`
- [ ] Test MT5 library import
- [ ] Connect to MT5 with credentials:
  - Server: MetaQuotes-Demo
  - Login: 5042856355
  - Password: V!QzRxQ7
  - Investor: J@LnDnC7
- [ ] Verify MT5 connection works

### Phase 3: Code Deployment
- [ ] Push mt5-api-bridge to GitHub
- [ ] Clone repository on VPS
- [ ] Create .env file with production credentials
- [ ] Install Python dependencies
- [ ] Test JWT authentication locally on VPS

### Phase 4: Service Setup
- [ ] Run deployment script (deploy_vps.sh)
- [ ] Configure systemd service
- [ ] Start mt5-api service
- [ ] Verify service is running

### Phase 5: Web Server & SSL
- [ ] Configure Nginx for trade.trainflow.dev
- [ ] Set up SSL certificate (Let's Encrypt)
- [ ] Test HTTPS access
- [ ] Verify CORS is working

### Phase 6: Final Testing
- [ ] Test health endpoint
- [ ] Test JWT authentication with real token
- [ ] Test historical data endpoint
- [ ] Test account info endpoint
- [ ] Verify all endpoints are accessible

## 🔐 MT5 Credentials

```
Server: MetaQuotes-Demo
Login: 5042856355
Password: V!QzRxQ7
Investor: J@LnDnC7
```

## 🌐 VPS Details

```
IP: 147.182.206.223
User: root
Domain: trade.trainflow.dev
```

## 📝 Notes

- Keep MT5 Terminal running after login
- Service will auto-restart on failure
- Logs available via: `journalctl -u mt5-api -f`

