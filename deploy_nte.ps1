# NTE Recommendation Engine - Deployment Script
# Run this from Windows PowerShell

$PI_IP = "100.89.162.22"
$PI_USER = "sahan"

Write-Host "🚀 Starting NTE Recommendation Engine Deployment..." -ForegroundColor Green
Write-Host ""

# Step 1: Deploy files
Write-Host "📁 Step 1: Deploying files to Pi..." -ForegroundColor Cyan
scp nte_server.py ${PI_USER}@${PI_IP}:/home/sahan/
scp nte-server.service ${PI_USER}@${PI_IP}:/home/sahan/
scp index.html ${PI_USER}@${PI_IP}:/home/sahan/test_dashboard.html

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Files deployed successfully" -ForegroundColor Green
}
else {
    Write-Host "❌ File deployment failed" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 2: Install dependencies
Write-Host "📦 Step 2: Installing Python dependencies..." -ForegroundColor Cyan
ssh ${PI_USER}@${PI_IP} "pip3 install fastapi uvicorn paho-mqtt --break-system-packages"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Dependencies installed" -ForegroundColor Green
}
else {
    Write-Host "⚠️ Dependency installation had issues (may already be installed)" -ForegroundColor Yellow
}

Write-Host ""

# Step 3: Setup systemd service
Write-Host "⚙️ Step 3: Setting up systemd service..." -ForegroundColor Cyan
ssh ${PI_USER}@${PI_IP} @"
sudo cp /home/sahan/nte-server.service /etc/systemd/system/ && \
sudo systemctl daemon-reload && \
sudo systemctl enable nte-server && \
echo '✅ Service enabled'
"@

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Systemd service configured" -ForegroundColor Green
}
else {
    Write-Host "❌ Service setup failed" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 4: Start/Restart services
Write-Host "🔄 Step 4: Starting services..." -ForegroundColor Cyan
ssh ${PI_USER}@${PI_IP} @"
sudo systemctl restart nte-server && \
sudo systemctl restart pi-test-dashboard && \
echo '✅ Services restarted'
"@

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Services started successfully" -ForegroundColor Green
}
else {
    Write-Host "❌ Service start failed" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 5: Verify installation
Write-Host "🔍 Step 5: Verifying installation..." -ForegroundColor Cyan
Write-Host ""

Write-Host "NTE Server Status:" -ForegroundColor Yellow
ssh ${PI_USER}@${PI_IP} "sudo systemctl status nte-server --no-pager -l | head -n 15"

Write-Host ""
Write-Host "Test Dashboard Status:" -ForegroundColor Yellow
ssh ${PI_USER}@${PI_IP} "sudo systemctl status pi-test-dashboard --no-pager -l | head -n 15"

Write-Host ""

# Step 6: Health check
Write-Host "🏥 Step 6: Health checks..." -ForegroundColor Cyan
Write-Host ""

Write-Host "NTE Server Health:" -ForegroundColor Yellow
ssh ${PI_USER}@${PI_IP} "curl -s http://localhost:8886/health | python3 -m json.tool"

Write-Host ""
Write-Host ""

# Final summary
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "✅ NTE RECOMMENDATION ENGINE DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green
Write-Host ""
Write-Host "📊 Access Points:" -ForegroundColor Cyan
Write-Host "  • Test Dashboard: http://192.168.1.232:8090/" -ForegroundColor White
Write-Host "  • NTE API: http://192.168.1.232:8886/" -ForegroundColor White
Write-Host "  • NTE Health: http://192.168.1.232:8886/health" -ForegroundColor White
Write-Host ""
Write-Host "📚 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Open test dashboard" -ForegroundColor White
Write-Host "  2. Scroll to 'NTE Recommendation Engine' section" -ForegroundColor White
Write-Host "  3. Register a baby with birth date/time and weight" -ForegroundColor White
Write-Host "  4. Select baby from dropdown" -ForegroundColor White
Write-Host "  5. Click 'Start' to begin monitoring" -ForegroundColor White
Write-Host ""
Write-Host "📖 Documentation: NTE_INTEGRATION_GUIDE.md" -ForegroundColor Cyan
Write-Host ""
