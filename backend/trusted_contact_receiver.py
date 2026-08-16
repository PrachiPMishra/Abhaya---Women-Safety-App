import time
import os
import sys
from datetime import datetime
from database import get_db_connection

def clear_screen():
    os.system('clear' if os.name == 'posix' else 'cls')

def main():
    seen_dispatches = set()
    
    print("\n" + "=" * 65)
    print(" 📱 [ABHAYA TRUSTED CONTACT MOBILE RECEIVER TERMINAL]")
    print(" Status: ACTIVE & LISTENING FOR EMERGENCY SMS ALERTS...")
    print(" Press Ctrl+C at any time to exit.")
    print("=" * 65 + "\n")
    sys.stdout.flush()

    while True:
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM sos_dispatches ORDER BY created_at ASC")
            rows = cursor.fetchall()
            conn.close()

            for row in rows:
                disp_id = row["dispatch_id"]
                if disp_id not in seen_dispatches:
                    seen_dispatches.add(disp_id)

                    session_id = row["session_id"]
                    name = row["recipient_name"]
                    phone = row["recipient_phone"]
                    title = row["title"]
                    body = row["body"]
                    is_critical = bool(row["is_critical"])
                    created_at = row["created_at"]

                    time_str = datetime.now().strftime("%H:%M:%S")

                    if is_critical:
                        header_tag = "🚨🚨🚨 [CRITICAL POLICE ESCALATION SMS RECEIVED] 🚨🚨🚨"
                        box_border = "🔴" * 25
                    else:
                        header_tag = "🔔 [INCOMING EMERGENCY SOS SMS RECEIVED]"
                        box_border = "⚡" * 25

                    alert_output = (
                        f"\n{box_border}\n"
                        f"  {header_tag}\n"
                        f"  ⏱️  Timestamp: {time_str} ({created_at})\n"
                        f"  📱  Target Trusted Contact: {name}\n"
                        f"  📞  Phone: {phone}\n"
                        f"  --------------------------------------------------\n"
                        f"{body}\n"
                        f"  --------------------------------------------------\n"
                        f"  ✅ [SMS STATUS: DELIVERED TO HANDSET INBOX]\n"
                        f"{box_border}\n"
                    )
                    print(alert_output, flush=True)

        except Exception as e:
            pass

        time.sleep(1)

if __name__ == "__main__":
    main()
