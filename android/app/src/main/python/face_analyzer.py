import face_recognition
import numpy as np
import base64
import io
import json
import os
from PIL import Image

# --- Yardımcı Fonksiyonlar ---

def _load_encodings(filepath):
    """
    Verilen yoldan JSON dosyasını okur ve yüz verilerini yükler.
    Dosya yoksa boş bir sözlük döndürür.
    """
    if os.path.exists(filepath):
        with open(filepath, 'r') as f:
            return json.load(f)
    return {}

def _save_encodings(filepath, data):
    """
    Verilen yüz verilerini JSON formatında dosyaya yazar.
    """
    with open(filepath, 'w') as f:
        json.dump(data, f)

def _base64_to_image(base64_string):
    """Base64 metnini NumPy resim dizisine çevirir."""
    image_data = base64.b64decode(base64_string)
    image = Image.open(io.BytesIO(image_data))
    return np.array(image)

# --- Ana Fonksiyonlar (Kotlin'den Çağrılacak) ---

def save_known_face(user_name, base64_string, encodings_filepath):
    """
    Yeni bir yüzü kullanıcı adıyla birlikte JSON dosyasına kaydeder.
    """
    try:
        # Mevcut kayıtları yükle
        known_faces = _load_encodings(encodings_filepath)

        image_np = _base64_to_image(base64_string)
        face_encodings = face_recognition.face_encodings(image_np)

        if len(face_encodings) > 0:
            # Resimdeki ilk yüzün kodlamasını al
            new_encoding = face_encodings[0].tolist() # JSON için listeye çevir

            # Kullanıcı adını ve kodlamayı kayıtlara ekle
            known_faces[user_name] = new_encoding
            
            # Güncellenmiş veriyi dosyaya yaz
            _save_encodings(encodings_filepath, known_faces)
            return True
        else:
            # Resimde yüz bulunamadı
            return False
            
    except Exception as e:
        print(f"Hata (save_known_face): {e}")
        return False


def recognize_face(base64_string_to_check, encodings_filepath):
    """
    Verilen bir yüzü, JSON dosyasındaki tüm kayıtlı yüzlerle karşılaştırır
    ve en iyi eşleşmeyi döndürür.
    """
    try:
        known_faces = _load_encodings(encodings_filepath)
        if not known_faces:
            return {"name": "unknown", "reason": "No faces registered"}

        # Kayıtlı isimleri ve kodlamaları ayrı listelere al
        known_face_names = list(known_faces.keys())
        known_face_encodings = list(known_faces.values())

        image_np = _base64_to_image(base64_string_to_check)
        unknown_face_encodings = face_recognition.face_encodings(image_np)

        if len(unknown_face_encodings) == 0:
            return {"name": "unknown", "reason": "No face found in image"}

        # Sadece ilk yüzü kontrol et
        unknown_encoding = unknown_face_encodings[0]

        # Bilinmeyen yüzü tüm bilinen yüzlerle karşılaştır
        matches = face_recognition.compare_faces(known_face_encodings, unknown_encoding, tolerance=0.6)
        
        # En iyi eşleşmeyi bulmak için mesafeleri hesapla
        face_distances = face_recognition.face_distance(known_face_encodings, unknown_encoding)
        best_match_index = np.argmin(face_distances)

        name = "unknown"
        distance = None

        if matches[best_match_index]:
            name = known_face_names[best_match_index]
            distance = face_distances[best_match_index]
        
        return {"name": name, "distance": distance}

    except Exception as e:
        print(f"Hata (recognize_face): {e}")
        return {"name": "error", "reason": str(e)}

def delete_all_faces(encodings_filepath):
    """
    Tüm kayıtlı yüz verilerini içeren JSON dosyasını siler.
    """
    try:
        if os.path.exists(encodings_filepath):
            os.remove(encodings_filepath)
        return True
    except Exception as e:
        print(f"Hata (delete_all_faces): {e}")
        return False

