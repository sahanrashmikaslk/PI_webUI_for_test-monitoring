# Edge Device Shutdown & Restart Feature

## Overview

Added shutdown and restart buttons for the Raspberry Pi edge device in the Admin Dashboard overview section.

## Changes Made

### 1. Backend API Functions (`admin.service.js`)

**File**: `incubator_monitoring_with_thingsboard_integration/react_dashboard/src/services/admin.service.js`

Added two new API functions:

- `shutdownPi(piHost)` - Sends POST request to `/shutdown` endpoint
- `rebootPi(piHost)` - Sends POST request to `/reboot` endpoint

Both functions use a 10-second timeout to handle network interruption during device shutdown/reboot.

### 2. Admin Dashboard UI (`AdminPanel.js`)

**File**: `incubator_monitoring_with_thingsboard_integration/react_dashboard/src/components/Admin/AdminPanel.js`

**Imports Added:**

```javascript
import { shutdownPi, rebootPi } from "../../services/admin.service";
```

**New State Variables:**

- `deviceAction` - Tracks current action: 'shutting-down', 'rebooting', or null
- `deviceActionError` - Stores error messages

**New Icons Added:**

- `ICONS.shutdown` - Power off icon
- `ICONS.restart` - Circular arrows icon

**New Handler Functions:**

- `handleShutdown()` - Shows confirmation dialog, calls shutdownPi API
- `handleReboot()` - Shows confirmation dialog, calls rebootPi API, auto-reconnects after 1 minute

**UI Components Added in Overview Section:**

- Device Control section with header
- Error display area
- Status indicator with spinner during actions
- Two control buttons:
  - **Restart Device** (blue theme) - Reboots Pi in 5 seconds
  - **Shutdown Device** (red theme) - Powers off Pi in 5 seconds

### 3. Styling (`AdminPanel.css`)

**File**: `incubator_monitoring_with_thingsboard_integration/react_dashboard/src/components/Admin/AdminPanel.css`

Added comprehensive styles:

- `.device-controls` - Main container with card styling
- `.device-controls__header` - Section title and description
- `.device-controls__error` - Red error alert box
- `.device-controls__status` - Blue status indicator with spinner
- `.device-controls__buttons` - Responsive grid layout
- `.device-control-btn` - Button base styles with hover effects
- `.device-control-btn--reboot` - Blue color scheme
- `.device-control-btn--shutdown` - Red color scheme
- Dark theme variants for all components
- Mobile responsive (stacks buttons on small screens)

## User Experience

### Confirmation Dialogs

Both actions show browser confirmation dialogs with warnings:

**Shutdown:**

```
⚠️ WARNING: This will shutdown the Raspberry Pi edge device.

The device will power off completely and will need to be manually powered back on.

Are you sure you want to proceed?
```

**Reboot:**

```
⚠️ WARNING: This will reboot the Raspberry Pi edge device.

All services will restart and the device will be unavailable for 1-2 minutes.

Are you sure you want to proceed?
```

### Visual Feedback

- **During Action**: Shows status message with animated spinner
- **Shutdown**: "Device is shutting down..."
- **Reboot**: "Device is rebooting... (will reconnect in ~1 min)"
- **On Error**: Red alert box with error message
- **Buttons Disabled**: During any ongoing action

### Auto-Reconnection

- After reboot command, dashboard waits 60 seconds then automatically refreshes snapshot
- During shutdown, status clears after 10 seconds

## Button Appearance

### Restart Button (Blue)

- Icon: Circular arrows (↻)
- Label: "Restart Device"
- Hint: "Reboot in 5 seconds"
- Color: Blue (#2563eb / #60a5fa)

### Shutdown Button (Red)

- Icon: Power symbol
- Label: "Shutdown Device"
- Hint: "Power off in 5 seconds"
- Color: Red (#dc2626 / #f87171)

Both buttons have:

- Hover effect: Lifts up, shows glow
- Disabled state: 50% opacity, no hover
- Smooth transitions: 0.25s cubic-bezier

## Backend Requirements

### Health Server Endpoints

The existing `simple_health_server.py` already has:

- `POST /shutdown` - Executes `sudo shutdown -h now` after 5 seconds
- `POST /reboot` - Executes `sudo reboot` after 5 seconds

### Permissions Setup Required

⚠️ **IMPORTANT**: You must configure sudo permissions on the Pi for passwordless shutdown/reboot.

See: `SETUP_PI_SHUTDOWN_PERMISSIONS.md` for detailed instructions.

**Quick Setup:**

```bash
# On Raspberry Pi
sudo nano /etc/sudoers.d/health-server

# Add this line (replace 'sahan' with your username):
sahan ALL=(ALL) NOPASSWD: /sbin/shutdown, /sbin/reboot

# Set permissions
sudo chmod 0440 /etc/sudoers.d/health-server

# Verify
sudo visudo -c
```

## Testing

### 1. Compile Test

✅ React dashboard compiles successfully on port 3001

### 2. UI Test

Navigate to Admin Panel → Overview section → Scroll down to "Edge Device Control"

### 3. API Test (On Pi)

```bash
# Test shutdown endpoint (BE CAREFUL - will actually shutdown!)
curl -X POST http://100.89.162.22:9000/shutdown

# Test reboot endpoint (BE CAREFUL - will actually reboot!)
curl -X POST http://100.89.162.22:9000/reboot
```

## Security Considerations

1. **Network Access**: Port 9000 should only be accessible from trusted networks
2. **Confirmation Required**: Browser dialogs prevent accidental clicks
3. **Limited Commands**: Sudoers config only allows shutdown/reboot, nothing else
4. **Specific User**: Only the service user can execute these commands
5. **Audit Trail**: All actions logged in system journal

## Location in Dashboard

**Path**: Admin Panel → Overview (first section)

The device control buttons appear:

- After the status cards grid
- After the health metrics bar
- Before the "Edge device services" section

## Responsive Design

- **Desktop**: Two buttons side-by-side
- **Mobile**: Buttons stack vertically
- **Tablet**: Responsive grid adjusts based on available width

## Dark Mode Support

All components have full dark mode styling:

- Translucent backgrounds with glassmorphism
- Adjusted colors for readability
- Proper contrast ratios maintained
- Icon colors match theme

## Files Modified

1. ✅ `admin.service.js` - Added API functions
2. ✅ `AdminPanel.js` - Added UI components and handlers
3. ✅ `AdminPanel.css` - Added styling

## Files Created

1. ✅ `SETUP_PI_SHUTDOWN_PERMISSIONS.md` - Setup guide for Pi permissions

## Next Steps

1. **Deploy to Pi**: Configure sudo permissions (see setup guide)
2. **Test in Production**: Verify buttons work with actual Pi
3. **Monitor Logs**: Check health server logs for any issues
4. **Security Review**: Ensure firewall rules are configured

## Known Limitations

1. No progress indicator during actual shutdown/reboot (device goes offline)
2. Auto-reconnect after reboot is time-based (60s), not connection-based
3. No way to cancel shutdown/reboot once initiated (5-second delay is minimal)
4. Requires manual power-on after shutdown

## Future Enhancements

- Real-time connection monitoring during reboot
- Cancellation mechanism (extend delay to 30s with cancel option)
- Wake-on-LAN support for remote power-on
- Schedule shutdown/reboot for maintenance windows
- Last action history/audit log in UI
