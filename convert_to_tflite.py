import tensorflow as tf

# Kaynak TensorFlow modelinin yolu (SavedModel formatında)
saved_model_dir = "assets/embeddinggemma-300M_seq1024_mixed-precision.tflite"

# TFLite converter oluştur
converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)

# Eski opsları kullan (bu EMDEDING_LOOKUP sorununu çözebilir)
converter.experimental_new_converter = False

# Modeli dönüştür
tflite_model = converter.convert()

# Çıktıyı kaydet
with open("model.tflite", "wb") as f:
    f.write(tflite_model)

print("TFLite model başarıyla oluşturuldu: model.tflite")
