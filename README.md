# ollama-model-file-link
<br>

## simple powershell script to take a model folder and replace imported models into ollama with symlinks to the model folder.

this eliminates the issue of storing 2 copies of models when using ollama along side other options 

<br> edit these lines:

```
# --- CONFIGURATION ---
$sourceRoot = "B:\models"                      # Your original .gguf files directory
$ollamaBlobs = "$env:USERPROFILE\.ollama\models\blobs"  # Ollama blob storage
```

to reflect the folder you store gguf models in and folder for your ollama model directory if customized, otherwise the above will use the ollama default

once edited you simply cd the directory containing this script and run 

```
./Link-OllamaBlobs.ps1
```

<br> ## Example 

```
 Processing: H:\AI\LLM\DavidAU\gemma-4-31B-it-Mystery-Fine-Tune-HERETIC-UNCENSORED-Thinking-Instruct-GGUF\gemma-4-31B-Mystery-Fine-Tune-HERETIC-UNCENSORED-INSTRUCT-<br> <br> <br> Q4_K_S.gguf
   SHA256: DE8E296A14BEC5C55D35D8890EC42B19226DD98B5A97208E2D5CD08E04117313
   No matching blob found. The model may not be imported in Ollama yet.
 
 Processing: H:\AI\LLM\DavidAU\gemma-4-31B-it-Mystery-Fine-Tune-HERETIC-UNCENSORED-Thinking-Instruct-GGUF\mmproj-F32.gguf
   SHA256: 51864913627E39EDACFD69E3484A899C70587A5190321B44126B64E39C5EF0FB
   No matching blob found. The model may not be imported in Ollama yet.
 
 Processing: H:\AI\LLM\DavidAU\gemma-4-E4B-it-The-DECKARD-Expresso-Universe-HERETIC-UNCENSORED-Thinking-GGUF\E4B-Gemma4-it-vl-HERE-DECKARD4-Q8_0.gguf
   SHA256: 79307AAE843E7910222645E3B8F5BF1C8E8CAEFEF66535C2DAD5575701955E35
   Match found in blob: F:\ollama\models\blobs\sha256-79307aae843e7910222645e3b8f5bf1c8e8caefef66535c2dad5575701955e35
   SUCCESS: Blob replaced with symlink.
```
