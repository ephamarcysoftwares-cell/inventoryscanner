 import cv2

def start_camera(source):
    print(f"[INFO] Connecting to camera: {source}")
    cap = cv2.VideoCapture(source)

    if not cap.isOpened():
        print("[ERROR] Camera not accessible!")
        return

    while True:
        ret, frame = cap.read()
        if not ret:
            print("[WARNING] Failed to read frame.")
            break

        cv2.imshow("Live Camera Feed", frame)

        if cv2.waitKey(1) & 0xFF == 27:  # ESC key to exit
            break

    cap.release()
    cv2.destroyAllWindows()

def main():
    print("""
    === CAMERA CONNECTION OPTIONS ===
    1. USB Webcam
    2. IP Webcam (HTTP)
    3. RTSP/NVR
    """)

    choice = input("Chagua aina ya kamera (1/2/3): ")

    if choice == "1":
        cam_index = input("Ingiza USB camera index (kwa kawaida ni 0): ")
        start_camera(int(cam_index))

    elif choice == "2":
        ip_url = input("Ingiza IP Camera HTTP URL (e.g. http://192.168.1.5:8080/video): ")
        start_camera(ip_url)

    elif choice == "3":
        rtsp_url = input("Ingiza RTSP URL ya kamera (e.g. rtsp://username:password@ip:554/stream): ")
        start_camera(rtsp_url)

    else:
        print("[ERROR] Chaguo si sahihi. Tafadhali jaribu tena.")

if __name__ == "__main__":
    main()
