"""
CryptoGuard — Blockchain Social Engineering Detection Demo
Flask backend serving THREE classifiers:
  1. TF-IDF + Logistic Regression (baseline)
  2. DistilBERT (general — trained on email corpora)
  3. DistilBERT (domain-adapted — fine-tuned on blockchain communications)
"""

import os
import re
import sys
import time
import threading
import numpy as np
import pandas as pd
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS

sys.stdout.reconfigure(encoding='utf-8')

BASE_DIR         = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR        = os.path.join(BASE_DIR, 'model_checkpoint')
ADAPTED_DIR      = os.path.join(BASE_DIR, 'model_checkpoint_adapted_final')
TRAIN_CSV        = os.path.join(BASE_DIR, 'data', 'processed', 'train.csv')

app = Flask(__name__)
CORS(app)

# Global model holders
distilbert_model    = None
adapted_model       = None
distilbert_tokenizer = None
tfidf_vectorizer    = None
lr_classifier       = None
models_ready        = False
load_status         = {"status": "loading", "message": "Initialising..."}

def clean_text(text):
    if not isinstance(text, str): return ''
    text = re.sub(r'<[^>]+>', ' ', text)
    text = re.sub(r'http\S+|www\S+', ' ', text)
    text = re.sub(r'\S+@\S+', ' ', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text.lower()

def load_models():
    global distilbert_model, adapted_model, distilbert_tokenizer
    global tfidf_vectorizer, lr_classifier, models_ready, load_status

    try:
        import torch
        from transformers import (DistilBertTokenizerFast,
                                  DistilBertForSequenceClassification)
        from sklearn.feature_extraction.text import TfidfVectorizer
        from sklearn.linear_model import LogisticRegression

        device = torch.device('cpu')

        # 1. TF-IDF baseline
        load_status = {"status": "loading", "message": "Loading TF-IDF baseline..."}
        train_df = pd.read_csv(TRAIN_CSV)
        tfidf_vectorizer = TfidfVectorizer(
            max_features=50000, ngram_range=(1,2), sublinear_tf=True)
        X_train = tfidf_vectorizer.fit_transform(train_df['text'])
        lr_classifier = LogisticRegression(max_iter=1000, C=1.0, random_state=42)
        lr_classifier.fit(X_train, train_df['label'])

        # 2. General DistilBERT
        load_status = {"status": "loading", "message": "Loading general DistilBERT..."}
        distilbert_tokenizer = DistilBertTokenizerFast.from_pretrained(MODEL_DIR)
        distilbert_model = DistilBertForSequenceClassification.from_pretrained(MODEL_DIR)
        distilbert_model.to(device)
        distilbert_model.eval()

        # 3. Domain-adapted DistilBERT
        load_status = {"status": "loading", "message": "Loading domain-adapted model..."}
        adapted_model = DistilBertForSequenceClassification.from_pretrained(ADAPTED_DIR)
        adapted_model.to(device)
        adapted_model.eval()

        models_ready = True
        load_status = {"status": "ready", "message": "All three models loaded and ready."}
        print("✓ All three models loaded successfully.")

    except Exception as e:
        load_status = {"status": "error", "message": str(e)}
        print(f"✗ Model loading failed: {e}")

def run_bert(model, tokenizer, text, device_str='cpu'):
    import torch
    cleaned = clean_text(text)
    inputs = tokenizer(
        cleaned, truncation=True, padding=True,
        max_length=256, return_tensors='pt')
    with torch.no_grad():
        outputs = model(**inputs)
        probs = torch.softmax(outputs.logits, dim=1)[0]
        phishing_prob = probs[1].item()
    return {
        "probability":    round(phishing_prob, 4),
        "prediction":     int(phishing_prob >= 0.5),
        "label":          "Phishing" if phishing_prob >= 0.5 else "Legitimate",
        "confidence_pct": round(phishing_prob * 100, 1)
    }

def run_tfidf(text):
    cleaned = clean_text(text)
    vec = tfidf_vectorizer.transform([cleaned])
    prob = lr_classifier.predict_proba(vec)[0][1]
    return {
        "probability":    round(prob, 4),
        "prediction":     int(prob >= 0.5),
        "label":          "Phishing" if prob >= 0.5 else "Legitimate",
        "confidence_pct": round(prob * 100, 1)
    }


@app.route('/')
def index():
    return send_from_directory(BASE_DIR, 'demo.html')

@app.route('/status')
def status():
    return jsonify(load_status)

@app.route('/classify', methods=['POST'])
def classify():
    if not models_ready:
        return jsonify({"error": "Models still loading", "status": load_status["message"]}), 503

    data = request.get_json()
    text = data.get('text', '').strip()
    if not text or len(text) < 5:
        return jsonify({"error": "Text too short"}), 400

    t0 = time.time()

    tfidf_result   = run_tfidf(text)
    bert_result    = run_bert(distilbert_model, distilbert_tokenizer, text)
    adapted_result = run_bert(adapted_model,    distilbert_tokenizer, text)

    elapsed = round((time.time() - t0) * 1000, 1)

    return jsonify({
        "text":          text[:200],
        "tfidf":         tfidf_result,
        "distilbert":    bert_result,
        "adapted":       adapted_result,
        "inference_ms":  elapsed
    })

if __name__ == '__main__':
    print("Starting CryptoGuard demo server (3-model mode)...")
    thread = threading.Thread(target=load_models, daemon=True)
    thread.start()
    print("Server starting at http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=False)