#!/usr/bin/env python3
"""Fix cry detector telemetry to ensure all fields have cry_ prefix"""

# Read the file
with open('/home/sahan/cry_detector.py', 'r') as f:
    content = f.read()

# Old telemetry section
old_section = '''            # Prepare base telemetry data
            telemetry = {
                'cry_detected': cry_status.get('cry_detected', False),
                'cry_audio_level': round(cry_status.get('audio_level', 0), 3),
                'cry_sensitivity': cry_status.get('sensitivity', 0.6),
                'cry_total_detections': cry_status.get('total_detections', 0),
                'cry_monitoring': cry_status.get('is_monitoring', False),
                'verified_cries': cry_status.get('verified_cries', 0),
                'false_positives': cry_status.get('false_positives', 0),
                'timestamp': int(time.time() * 1000)
            }

            # Add last cry time if available
            if cry_status.get('last_cry_time'):
                telemetry['cry_last_detected'] = cry_status['last_cry_time']

            # Add classification data if available
            if cry_status.get('classification'):
                telemetry['cry_classification'] = cry_status['classification']
                telemetry['cry_classification_confidence'] = cry_status.get('classification_confidence', 0)

                # Add top 3 probabilities for dashboard display
                if cry_status.get('classification_probabilities'):
                    probs = cry_status['classification_probabilities']
                    sorted_probs = sorted(probs.items(), key=lambda x: x[1], reverse=True)[:3]
                    telemetry['cry_classification_top1'] = f"{sorted_probs[0][0]}: {sorted_probs[0][1]:.2%}"
                    if len(sorted_probs) > 1:
                        telemetry['cry_classification_top2'] = f"{sorted_probs[1][0]}: {sorted_probs[1][1]:.2%}"
                    if len(sorted_probs) > 2:
                        telemetry['cry_classification_top3'] = f"{sorted_probs[2][0]}: {sorted_probs[2][1]:.2%}"

            # Add verification status
            if cry_status.get('verified'):
                telemetry['cry_verified'] = cry_status['verified']
                telemetry['cry_verification_confidence'] = cry_status.get('verification_confidence', 0)'''

# New telemetry section with cry_ prefix on all fields
new_section = '''            # Prepare base telemetry data (all fields prefixed with cry_)
            telemetry = {
                'cry_detected': cry_status.get('cry_detected', False),
                'cry_audio_level': round(cry_status.get('audio_level', 0), 3),
                'cry_sensitivity': cry_status.get('sensitivity', 0.6),
                'cry_total_detections': cry_status.get('total_detections', 0),
                'cry_monitoring': cry_status.get('is_monitoring', False),
                'cry_verified_cries': cry_status.get('verified_cries', 0),
                'cry_false_positives': cry_status.get('false_positives', 0),
                'timestamp': int(time.time() * 1000)
            }

            # Add last cry time if available
            if cry_status.get('last_cry_time'):
                telemetry['cry_last_detected'] = cry_status['last_cry_time']

            # Always add verification status (even if None/False)
            telemetry['cry_verified'] = cry_status.get('verified', False)
            telemetry['cry_verification_confidence'] = cry_status.get('verification_confidence', 0.0)

            # Add classification data if available
            if cry_status.get('classification'):
                telemetry['cry_classification'] = cry_status['classification']
                telemetry['cry_classification_confidence'] = cry_status.get('classification_confidence', 0)

                # Add top 3 probabilities for dashboard display
                if cry_status.get('classification_probabilities'):
                    probs = cry_status['classification_probabilities']
                    sorted_probs = sorted(probs.items(), key=lambda x: x[1], reverse=True)[:3]
                    telemetry['cry_classification_top1'] = f"{sorted_probs[0][0]}: {sorted_probs[0][1]:.2%}"
                    if len(sorted_probs) > 1:
                        telemetry['cry_classification_top2'] = f"{sorted_probs[1][0]}: {sorted_probs[1][1]:.2%}"
                    if len(sorted_probs) > 2:
                        telemetry['cry_classification_top3'] = f"{sorted_probs[2][0]}: {sorted_probs[2][1]:.2%}"
            else:
                # Always send classification fields, even if None
                telemetry['cry_classification'] = None
                telemetry['cry_classification_confidence'] = 0.0'''

# Replace
if old_section in content:
    content = content.replace(old_section, new_section)
    # Write back
    with open('/home/sahan/cry_detector.py', 'w') as f:
        f.write(content)
    print('✅ Updated telemetry: all fields have cry_ prefix and always sent')
else:
    print('❌ Could not find the old section to replace')
