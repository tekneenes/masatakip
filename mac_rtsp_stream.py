import cv2
import subprocess

# MacBook kamerası: 0
cap = cv2.VideoCapture(0)

if not cap.isOpened():
    print("Kamera açılamadı!")
    exit()

# RTSP yayın URL
rtsp_url = "rtsp://127.0.0.1:8554/mystream"

# GStreamer pipeline ile ffmpeg benzeri yayın
gst_command = f"""
gst-launch-1.0 -v fdsrc ! decodebin ! videoconvert ! x264enc tune=zerolatency bitrate=500 speed-preset=ultrafast ! rtspclientsink location={rtsp_url}
"""

# Subprocess ile pipeline başlat
proc = subprocess.Popen(gst_command, shell=True)

try:
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        # Frame işleme gerekiyorsa buraya ekle
        cv2.imshow("Preview", frame)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break
except KeyboardInterrupt:
    pass

cap.release()
cv2.destroyAllWindows()
proc.terminate()

