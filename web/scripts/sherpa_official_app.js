// Sherpa-ONNX WebAssembly Engine & Model Download Manager for 3erdh (عِرضْ)
console.log('[Sherpa] sherpa_official_app.js initialized.');

Module = {};

Module.locateFile = function(path, scriptDirectory = '') {
  if (path.endsWith('.wasm') && !path.startsWith('scripts/')) return 'scripts/' + path;
  if (scriptDirectory) return scriptDirectory + path;
  return path;
};

let recognizer = null;
let recognizer_stream = null;
let isRecognizerReady = false;
let isWasmLoaded = false;

Module.setStatus = function(status) {};

Module.printErr = function(text) {
  console.error('[Sherpa WASM Error]', text);
};

Module.onAbort = function(what) {
  console.error('[Sherpa WASM Aborted]', what);
  const titleAr = document.getElementById('model-modal-title-ar');
  const titleEn = document.getElementById('model-modal-title-en');
  const descAr = document.getElementById('model-modal-desc-ar');
  const descEn = document.getElementById('model-modal-desc-en');
  if (titleAr) titleAr.innerText = 'تعذر تشغيل المحرك';
  if (titleEn) titleEn.innerText = 'Engine Initialization Failed';
  if (descAr) descAr.innerText = 'يرجى تحديث الصفحة أو استخدام متصفح حديث مثل Chrome أو Safari.';
  if (descEn) descEn.innerText = 'Please reload or use a modern browser (Chrome/Safari/Edge).';
};

Module.onRuntimeInitialized = function() {
  console.log('[Sherpa] WASM module loaded into memory.');
  isWasmLoaded = true;
};

window.isWasmModuleLoaded = function() {
  return isWasmLoaded;
};

// Called by Dart to write asset bytes into WASM virtual filesystem
window.writeSherpaAssetToVFS = function(filename, bytes) {
  try {
    const fullPath = '/' + filename;
    if (Module.FS) {
      try {
        if (Module.FS.analyzePath && Module.FS.analyzePath(fullPath).exists) {
          Module.FS.unlink(fullPath);
        }
      } catch (_) {}
      Module.FS.writeFile(fullPath, bytes);
      console.log(`[Sherpa] Wrote ${filename} to VFS. Size: ${bytes.length || bytes.byteLength} bytes`);
      return true;
    } else if (Module.FS_createDataFile) {
      try {
        if (Module.FS_unlink) Module.FS_unlink(fullPath);
      } catch (_) {}
      Module.FS_createDataFile('/', filename, bytes, true, true, true);
      console.log(`[Sherpa] Wrote ${filename} to VFS via createDataFile. Size: ${bytes.length || bytes.byteLength} bytes`);
      return true;
    } else {
      console.error('[Sherpa] No FS API found on Module!');
      return false;
    }
  } catch (e) {
    console.error(`[Sherpa] Failed to write ${filename} to VFS:`, e);
    return false;
  }
};

// Called by Dart after writing model files to initialize recognizer
window.initSherpaRecognizer = function(modelFilename) {
  try {
    if (modelFilename) {
      Module.modelPath = modelFilename.startsWith('./') ? modelFilename : ('./' + modelFilename);
    }
    recognizer = createOnlineRecognizer(Module);
    if (!recognizer || !recognizer.handle) {
      throw new Error('OnlineRecognizer created with null or invalid handle');
    }
    isRecognizerReady = true;
    console.log("[Sherpa] Recognizer created successfully!");

    // Free VFS RAM immediately (model is compiled in C++ recognizer)
    try {
      const modelFile = modelFilename || 'zipformer_p_arabic_v3.int8.onnx';
      const fullPath = modelFile.startsWith('/') ? modelFile : ('/' + modelFile);
      if (Module.FS && Module.FS.analyzePath && Module.FS.analyzePath(fullPath).exists) {
        Module.FS.unlink(fullPath);
        console.log(`[Sherpa] Unlinked ${fullPath} from VFS to reclaim RAM.`);
      }
    } catch(unlinkErr) {
      console.warn('[Sherpa] Non-critical unlink notice:', unlinkErr);
    }
    activeModelDownloadPromise = null;
    
    // Hide download modal if active
    const modal = document.getElementById('model-download-modal');
    if (modal) {
      modal.style.opacity = '0';
      setTimeout(() => { modal.style.display = 'none'; }, 300);
    }
    return true;
  } catch (e) {
    console.error('[Sherpa] Failed to create recognizer:', e);
    const modal = document.getElementById('model-download-modal');
    if (modal) modal.style.display = 'none';
    return false;
  }
};

let audioCtx;
let mediaStream;
let expectedSampleRate = 16000;
let recordSampleRate;  
let recorder = null;   

let lastResult = '';
let processedChunks = 0;
let frameBuffer = new Float32Array(0);
const RECORD_CHUNK_SAMPLES = 5120; // 320ms at 16000Hz

function downsampleBuffer(buffer, exportSampleRate) {
  if (exportSampleRate === recordSampleRate) return buffer;
  var sampleRateRatio = recordSampleRate / exportSampleRate;
  var newLength = Math.round(buffer.length / sampleRateRatio);
  var result = new Float32Array(newLength);
  var offsetResult = 0;
  var offsetBuffer = 0;
  while (offsetResult < result.length) {
    var nextOffsetBuffer = Math.round((offsetResult + 1) * sampleRateRatio);
    var accum = 0, count = 0;
    for (var i = offsetBuffer; i < nextOffsetBuffer && i < buffer.length; i++) {
      accum += buffer[i];
      count++;
    }
    result[offsetResult] = accum / count;
    offsetResult++;
    offsetBuffer = nextOffsetBuffer;
  }
  return result;
}

function primeRecognizer() {
  if (recognizer && recognizer_stream) {
    let primingBuffer = new Float32Array(4800); // 300ms at 16000Hz
    recognizer_stream.acceptWaveform(expectedSampleRate, primingBuffer);
    while (recognizer.isReady(recognizer_stream)) {
      recognizer.decode(recognizer_stream);
    }
  }
}

let workletNode = null;

function processAudioSamples(samples) {
  processedChunks++;

  if (!isRecognizerReady || !recognizer) {
    return;
  }

  if (recognizer_stream == null) {
    recognizer_stream = recognizer.createStream();
    primeRecognizer();
  }

  recognizer_stream.acceptWaveform(expectedSampleRate, samples);
  while (recognizer.isReady(recognizer_stream)) {
    recognizer.decode(recognizer_stream);
  }

  let isEndpoint = recognizer.isEndpoint(recognizer_stream);
  let fullResult = recognizer.getResult(recognizer_stream);
  let resultText = fullResult.text;

  if (resultText.length > 0 && lastResult != resultText) {
    lastResult = resultText;
    if (window.dartSherpaOnResult) {
      window.dartSherpaOnResult(JSON.stringify(fullResult), false);
    }
  }

  if (isEndpoint) {
    if (window.dartSherpaOnResult) {
      window.dartSherpaOnResult(JSON.stringify(fullResult), true);
    }
  }
}

let activeMicrophoneStream = null;

window.startOfficialSherpa = function() {
  if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
    console.error('[Sherpa] getUserMedia not supported on your browser!');
    return;
  }

  const constraints = {
    audio: {
      autoGainControl: false,
      echoCancellation: false,
      noiseSuppression: false
    }
  };

  let onSuccess = async function(stream) {
    activeMicrophoneStream = stream;
    
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!audioCtx) {
      try {
        audioCtx = new AudioContextClass({sampleRate: 16000});
      } catch(e) {
        audioCtx = new AudioContextClass();
      }
    }
    
    if (audioCtx.state === 'suspended') {
      audioCtx.resume().catch(console.warn);
    }

    recordSampleRate = audioCtx.sampleRate;
    mediaStream = audioCtx.createMediaStreamSource(stream);

    let usedWorklet = false;
    if (audioCtx.audioWorklet) {
      try {
        await audioCtx.audioWorklet.addModule('scripts/audio_worklet.js');
        workletNode = new AudioWorkletNode(audioCtx, 'audio-stream-processor');
        workletNode.port.onmessage = (event) => {
          if (event.data && event.data.samples) {
            const chunk = new Float32Array(event.data.samples);
            processAudioSamples(chunk);
          }
        };
        mediaStream.connect(workletNode);
        workletNode.connect(audioCtx.destination);
        usedWorklet = true;
      } catch (workletErr) {
        console.warn('[Sherpa] AudioWorklet failed, fallback ScriptProcessor:', workletErr);
      }
    }

    if (!usedWorklet) {
      var bufferSize = 4096;
      if (audioCtx.createScriptProcessor) {
        recorder = audioCtx.createScriptProcessor(bufferSize, 1, 2);
      } else {
        recorder = audioCtx.createJavaScriptNode(bufferSize, 1, 2);
      }

      recorder.onaudioprocess = function(e) {
        let samples = new Float32Array(e.inputBuffer.getChannelData(0));
        samples = downsampleBuffer(samples, expectedSampleRate);

        let newBuffer = new Float32Array(frameBuffer.length + samples.length);
        newBuffer.set(frameBuffer);
        newBuffer.set(samples, frameBuffer.length);
        frameBuffer = newBuffer;

        let offset = 0;
        while (frameBuffer.length - offset >= RECORD_CHUNK_SAMPLES) {
          let chunk = frameBuffer.slice(offset, offset + RECORD_CHUNK_SAMPLES);
          offset += RECORD_CHUNK_SAMPLES;
          processAudioSamples(chunk);
        }

        if (offset < frameBuffer.length) {
          frameBuffer = frameBuffer.slice(offset);
        } else {
          frameBuffer = new Float32Array(0);
        }
      };

      mediaStream.connect(recorder);
      recorder.connect(audioCtx.destination);
    }
  };

  let onError = function(err) {
    console.error('[Sherpa] Microphone access error:', err);
  };

  navigator.mediaDevices.getUserMedia(constraints).then(onSuccess, onError);
};

window.stopOfficialSherpa = function() {
  if (workletNode && audioCtx) {
    try { workletNode.disconnect(audioCtx.destination); } catch(e) {}
    try { workletNode.port.close(); } catch(e) {}
    workletNode = null;
  }
  if (mediaStream && workletNode) {
    try { mediaStream.disconnect(workletNode); } catch(e) {}
  }
  if (recorder && audioCtx) {
    try { recorder.disconnect(audioCtx.destination); } catch(e) {}
    recorder = null;
  }
  if (mediaStream && recorder) {
    try { mediaStream.disconnect(recorder); } catch(e) {}
  }
  if (activeMicrophoneStream) {
    try {
      activeMicrophoneStream.getTracks().forEach(track => track.stop());
    } catch(e) {}
    activeMicrophoneStream = null;
  }
  
  if (lastResult.length > 0 && window.dartSherpaOnResult) {
    window.dartSherpaOnResult(JSON.stringify({ text: lastResult, isFinal: true }), true); 
  }
  lastResult = '';

  if (recognizer && recognizer_stream) {
    recognizer.reset(recognizer_stream);
    primeRecognizer();
  }
  frameBuffer = new Float32Array(0);
};

window.resetOfficialSherpaBuffer = function() {
  if (recognizer && recognizer_stream) {
    recognizer.reset(recognizer_stream);
    primeRecognizer();
    lastResult = '';
    frameBuffer = new Float32Array(0);
  }
};

window.getOfficialSherpaError = function() {
  return '';
};

window.isOfficialSherpaReady = function() {
  return isRecognizerReady;
};

// --- IndexedDB Storage Helpers ---
const DB_NAME = 'SherpaModelDB';
const STORE_NAME = 'models';

function openDB() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, 1);
    request.onupgradeneeded = (e) => {
      const db = e.target.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME);
      }
    };
    request.onsuccess = (e) => resolve(e.target.result);
    request.onerror = (e) => reject(e.target.error);
  });
}

async function getCachedModel(key) {
  try {
    const db = await openDB();
    return new Promise((resolve) => {
      if (!db.objectStoreNames.contains(STORE_NAME)) { resolve(null); return; }
      const tx = db.transaction(STORE_NAME, 'readonly');
      const store = tx.objectStore(STORE_NAME);
      const req = store.get(key);
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => resolve(null);
    });
  } catch(e) { return null; }
}

async function ensurePersistentStorage() {
  try {
    if (navigator.storage && navigator.storage.persist) {
      const isPersisted = await navigator.storage.persist();
      console.log(`[Storage] Persistent storage active: ${isPersisted}`);
    }
  } catch (e) {
    console.warn('[Storage] Could not request persistent storage:', e);
  }
}

async function cacheModel(key, buffer) {
  try {
    const db = await openDB();
    return new Promise((resolve) => {
      try {
        const tx = db.transaction(STORE_NAME, 'readwrite');
        const store = tx.objectStore(STORE_NAME);
        const req = store.put(buffer, key);
        tx.oncomplete = () => {
          ensurePersistentStorage();
          resolve();
        };
        tx.onerror = () => resolve();
        tx.onabort = () => resolve();
        req.onerror = () => resolve();
      } catch(err) {
        resolve();
      }
    });
  } catch(e) {
    console.warn('[Sherpa] IndexedDB caching error:', e);
  }
}

let activeModelDownloadPromise = null;

// Multi-key finder for cached models
async function findCachedModel(keys) {
  for (const k of keys) {
    if (!k) continue;
    const buf = await getCachedModel(k);
    if (buf && buf.byteLength > 50000000) {
      console.log(`[Sherpa] Found valid model in IndexedDB under key: "${k}" (${buf.byteLength} bytes)`);
      return buf;
    }
  }
  return null;
}

// Fetches the ONNX model from IndexedDB or downloads on demand with 4-way parallel streaming & resume
window.fetchSherpaModel = async function(url) {
  if (activeModelDownloadPromise) {
    return activeModelDownloadPromise;
  }

  // Helper to inject WASM script dynamically to prevent UI lag on boot
  function injectWasmScript() {
    if (document.getElementById('sherpa-wasm-script')) return;
    const script = document.createElement('script');
    script.id = 'sherpa-wasm-script';
    script.src = 'scripts/sherpa-onnx-wasm-main-asr.js?v=10';
    document.body.appendChild(script);
    console.log('[Sherpa] Injected WASM script dynamically.');
  }

  activeModelDownloadPromise = (async () => {
    try {
      const canonicalKey = 'zipformer_p_arabic_v3.int8.onnx';
      const directUrl = 'https://github.com/Iam-Muslim/Natlu/releases/download/models-latest/zipformer_p_arabic_v3.int8.onnx';
      const lookupKeys = [url, canonicalKey, directUrl];

      // 1. Check if model is already stored in IndexedDB (>50MB)
      const cachedBuffer = await findCachedModel(lookupKeys);
      if (cachedBuffer) {
        injectWasmScript();
        return new Uint8Array(cachedBuffer);
      }

      // 2. Model not found in cache: Display Acceptance Modal
      const modal = document.getElementById('model-download-modal');
      const promptSection = document.getElementById('model-prompt-section');
      const progressSection = document.getElementById('model-progress-section');
      const acceptBtn = document.getElementById('model-accept-btn');
      const cancelBtn = document.getElementById('model-cancel-btn');

      if (modal) {
        modal.style.display = 'flex';
        modal.style.opacity = '1';
        if (promptSection) promptSection.style.display = 'block';
        if (progressSection) progressSection.style.display = 'none';
      }

      // Wait for user confirmation
      const userChoice = await new Promise((resolve) => {
        if (!acceptBtn) { resolve(true); return; }
        
        const onAccept = () => {
          if (cancelBtn) cancelBtn.removeEventListener('click', onCancel);
          resolve(true);
        };
        const onCancel = () => {
          if (acceptBtn) acceptBtn.removeEventListener('click', onAccept);
          resolve(false);
        };

        acceptBtn.addEventListener('click', onAccept, { once: true });
        if (cancelBtn) cancelBtn.addEventListener('click', onCancel, { once: true });
      });

      if (!userChoice) {
        console.log('[Sherpa] User cancelled model download.');
        if (modal) {
          modal.style.opacity = '0';
          setTimeout(() => { modal.style.display = 'none'; }, 300);
        }
        activeModelDownloadPromise = null;
        return null;
      }

      injectWasmScript();

      // Switch modal to Progress view
      if (promptSection) promptSection.style.display = 'none';
      if (progressSection) progressSection.style.display = 'block';

      const fill = document.getElementById('model-progress-fill');
      const text = document.getElementById('model-progress-text');
      if (fill) fill.style.width = '0%';
      if (text) text.innerText = '0%';

      // Helper: Single Stream Downloader
      async function downloadSingleStream(targetUrl) {
        return new Promise((resolve, reject) => {
          const xhr = new XMLHttpRequest();
          xhr.open('GET', targetUrl, true);
          xhr.responseType = 'arraybuffer';
          
          let lastUiUpdate = 0;
          xhr.onprogress = (event) => {
            if (event.lengthComputable) {
              const total = event.total;
              const loaded = event.loaded;
              const now = performance.now();
              if (now - lastUiUpdate > 60 || loaded === total) {
                lastUiUpdate = now;
                const percent = Math.min(100, Math.round((loaded / total) * 100));
                if (fill) fill.style.width = percent + '%';
                if (text) text.innerText = percent + '% (' + Math.round(loaded/1048576) + 'MB / ' + Math.round(total/1048576) + 'MB)';
              }
            }
          };
          
          xhr.onload = () => {
            if (xhr.status >= 200 && xhr.status < 300) {
              resolve(xhr.response);
            } else {
              reject(new Error(`HTTP status: ${xhr.status}`));
            }
          };
          xhr.onerror = () => reject(new Error('Network Error'));
          xhr.send();
        });
      }

      // Helper: Parallel Chunk Downloader with Per-Chunk Retry and Resume
      async function downloadParallelStream(targetUrl, numChunks = 4) {
        let lastUiUpdate = 0;
        function updateProgress(loaded, total) {
          const now = performance.now();
          if (now - lastUiUpdate > 60 || loaded === total) {
            lastUiUpdate = now;
            const percent = Math.min(100, Math.round((loaded / total) * 100));
            if (fill) fill.style.width = percent + '%';
            if (text) text.innerText = percent + '% (' + Math.round(loaded / 1048576) + 'MB / ' + Math.round(total / 1048576) + 'MB)';
          }
        }

        let totalSize = 72705392;
        try {
          const headRes = await fetch(targetUrl, { method: 'HEAD' });
          const len = headRes.headers.get('content-length');
          if (len) {
            const parsed = parseInt(len, 10);
            if (parsed > 10000000) totalSize = parsed;
          }
        } catch(e) {}

        const chunkSize = Math.ceil(totalSize / numChunks);
        const loadedPerChunk = new Array(numChunks).fill(0);

        // Fetch single chunk with automatic retry & resume
        async function fetchChunkWithRetry(start, end, chunkIndex, maxRetries = 3) {
          for (let attempt = 1; attempt <= maxRetries; attempt++) {
            try {
              return await new Promise((resolve, reject) => {
                const xhr = new XMLHttpRequest();
                xhr.open('GET', targetUrl, true);
                xhr.responseType = 'arraybuffer';
                xhr.setRequestHeader('Range', `bytes=${start}-${end}`);

                xhr.onprogress = (e) => {
                  loadedPerChunk[chunkIndex] = e.loaded;
                  const totalLoaded = loadedPerChunk.reduce((a, b) => a + b, 0);
                  updateProgress(totalLoaded, totalSize);
                };

                xhr.onload = () => {
                  if (xhr.status === 206) {
                    loadedPerChunk[chunkIndex] = xhr.response.byteLength;
                    const totalLoaded = loadedPerChunk.reduce((a, b) => a + b, 0);
                    updateProgress(totalLoaded, totalSize);
                    resolve({ index: chunkIndex, buffer: xhr.response });
                  } else if (xhr.status === 200) {
                    // Server doesn't support Range requests; signal fallback
                    reject(new Error(`Server returned HTTP 200 instead of 206 for chunk ${chunkIndex}`));
                  } else {
                    reject(new Error(`Chunk ${chunkIndex} HTTP ${xhr.status}`));
                  }
                };

                xhr.onerror = () => reject(new Error(`Chunk ${chunkIndex} network error`));
                xhr.send();
              });
            } catch (chunkErr) {
              console.warn(`[Sherpa] Chunk ${chunkIndex} attempt ${attempt} failed:`, chunkErr);
              if (attempt === maxRetries) throw chunkErr;
              await new Promise(r => setTimeout(r, 800 * attempt));
            }
          }
        }

        const chunkPromises = [];
        for (let i = 0; i < numChunks; i++) {
          const start = i * chunkSize;
          const end = Math.min(start + chunkSize - 1, totalSize - 1);
          chunkPromises.push(fetchChunkWithRetry(start, end, i));
        }

        const results = await Promise.all(chunkPromises);
        results.sort((a, b) => a.index - b.index);
        
        let totalBytes = 0;
        for (const r of results) totalBytes += r.buffer.byteLength;

        const assembled = new Uint8Array(totalBytes);
        let offset = 0;
        for (const r of results) {
          assembled.set(new Uint8Array(r.buffer), offset);
          offset += r.buffer.byteLength;
          r.buffer = null;
        }
        results.length = 0;

        return assembled.buffer;
      }

      // Candidate URLs: 1. Cloudflare/local proxy, 2. Direct GitHub release CDN, 3. Local bundled assets
      const candidateUrls = [
        url,
        directUrl,
        'assets/assets/model/zipformer_p_arabic_v3.int8.onnx',
        'assets/model/zipformer_p_arabic_v3.int8.onnx'
      ];

      let arrayBuffer = null;
      for (const targetUrl of candidateUrls) {
        if (!targetUrl) continue;
        try {
          console.log(`[Sherpa] Downloading model from: ${targetUrl}`);
          arrayBuffer = await downloadParallelStream(targetUrl, 4);
          if (arrayBuffer && arrayBuffer.byteLength > 50000000) break;
        } catch(parallelErr) {
          console.warn(`[Sherpa] Parallel range download failed for ${targetUrl}, falling back to single stream:`, parallelErr);
          try {
            arrayBuffer = await downloadSingleStream(targetUrl);
            if (arrayBuffer && arrayBuffer.byteLength > 50000000) break;
          } catch(singleErr) {
            console.warn(`[Sherpa] Single stream failed for ${targetUrl}:`, singleErr);
          }
        }
      }

      if (!arrayBuffer || arrayBuffer.byteLength < 10000000) {
        throw new Error('Could not download model from any available source.');
      }

      if (fill) fill.style.width = '100%';
      if (text) text.innerText = '100% (' + Math.round(arrayBuffer.byteLength / 1048576) + 'MB / ' + Math.round(arrayBuffer.byteLength / 1048576) + 'MB)';

      const pTitleAr = document.getElementById('model-progress-title-ar');
      const pTitleEn = document.getElementById('model-progress-title-en');
      const pDescAr = document.getElementById('model-progress-desc-ar');
      const pDescEn = document.getElementById('model-progress-desc-en');
      if (pTitleAr) pTitleAr.innerText = 'جارٍ تهيئة المحرك...';
      if (pTitleEn) pTitleEn.innerText = 'Initializing Engine...';
      if (pDescAr) pDescAr.innerText = 'قاربت العملية على الانتهاء...';
      if (pDescEn) pDescEn.innerText = 'Almost ready...';

      // 4. Save to IndexedDB across all lookup keys for seamless offline usage
      console.log('[Sherpa] Saving model to IndexedDB for offline usage...');
      await cacheModel(url, arrayBuffer);
      await cacheModel(canonicalKey, arrayBuffer);
      await cacheModel(directUrl, arrayBuffer);

      return new Uint8Array(arrayBuffer);
    } catch (e) {
      console.error('[Sherpa] Failed to fetch model:', e);
      const text = document.getElementById('model-progress-text');
      if (text) {
        text.innerText = 'خطأ في التحميل • Download failed';
        text.style.color = '#ef4444';
      }
      setTimeout(() => {
        const modal = document.getElementById('model-download-modal');
        if (modal) {
          modal.style.opacity = '0';
          setTimeout(() => { modal.style.display = 'none'; }, 300);
        }
      }, 2500);
      activeModelDownloadPromise = null;
      return null;
    }
  })();

  return activeModelDownloadPromise;
};
