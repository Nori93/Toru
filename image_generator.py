import random
import os

from diffusers import StableDiffusionPipeline, DiffusionPipeline
from diffusers.utils import export_to_video
import torch
from PIL import Image

try:
    # Preferred on Windows hosts with DirectML-capable GPUs
    import torch_directml  # type: ignore[import]
except Exception:  # pragma: no cover - optional, not available in Linux containers
    torch_directml = None  # type: ignore[assignment]


pipe = None


def _truncate_prompt(prompt: str, max_words: int = 45) -> str:
    """Truncate very long prompts so they fit the model's max token length.

    If the diffusion pipeline's tokenizer is available, use it with
    ``truncation=True`` and its ``model_max_length`` so we *guarantee* the
    text encoder never receives more tokens than it supports (typically 77
    for CLIP-based text encoders). As a fallback, limit by word count.
    """

    global pipe

    # Prefer exact truncation using the pipeline's tokenizer when possible
    try:
        if pipe is not None and hasattr(pipe, "tokenizer") and pipe.tokenizer is not None:
            tokenizer = pipe.tokenizer
            max_len = getattr(tokenizer, "model_max_length", 77) or 77

            encoded = tokenizer(
                prompt,
                truncation=True,
                max_length=max_len,
                return_attention_mask=False,
                return_token_type_ids=False,
            )

            input_ids = encoded["input_ids"]
            # tokenizers may return list[int] or list[list[int]]
            if input_ids and isinstance(input_ids[0], list):
                ids = input_ids[0]
            else:
                ids = input_ids

            return tokenizer.decode(ids, skip_special_tokens=True)
    except Exception:
        # If anything goes wrong, fall back to simple word-based truncation.
        pass

    # Fallback: conservative word-based truncation
    words = prompt.split()
    if len(words) <= max_words:
        return prompt
    return " ".join(words[:max_words])


# Select the best available device.
# - DirectML (Windows host) when torch_directml is available
# - CUDA if available in the environment
# - Otherwise, CPU (works everywhere, but slower)
if torch_directml is not None:
    device = torch_directml.device()
elif torch.cuda.is_available():
    device = torch.device("cuda")
else:
    device = torch.device("cpu")
MODLE_ID = "cagliostrolab/animagine-xl-4.0"
NEGATIVE_PROMPT = "blurry, low quality, bad anatomy, distorted face, extra limbs"
WIDTH = 512
HEIGHT = 768
NUM_INFERENCE_STEPS = 20
os.makedirs("assets", exist_ok=True)


def _next_generated_image_id() -> int:
    """Return the next integer ID for a generated image.

    Images are stored under assets/generated as img_<id>.png.
    """

    generated_dir = os.path.join("assets", "generated")
    os.makedirs(generated_dir, exist_ok=True)

    max_id = 0
    for name in os.listdir(generated_dir):
        if not name.startswith("img_") or not name.endswith(".png"):
            continue
        try:
            num = int(name[4:-4])
        except ValueError:
            continue
        if num > max_id:
            max_id = num

    return max_id + 1

def load_pipeline():
    global pipe
    if pipe is None:
        # Use float16 on GPU/DirectML, float32 on CPU for compatibility
        dtype = torch.float16 if getattr(device, "type", None) != "cpu" else torch.float32

        pipe = StableDiffusionPipeline.from_pretrained(
                MODLE_ID,
                torch_dtype=dtype,
                custom_pipeline="lpw_stable_diffusion_xl",
                add_watermarker=False,
                safety_checker=None  # Disable safety checker for NSFW content
        )

        # Move pipeline to the selected device
        if torch_directml is not None:
            pipe = pipe.to(device)
        else:
            # device is a torch.device for CUDA/CPU
            pipe = pipe.to(device)
    return pipe

def load_fireRed_pipeline():
    global pipe
    if pipe is None:
        pipe = DiffusionPipeline.from_pretrained(
                "FireRedTeam/FireRed-Image-Edit-1.0", 
                #torch_dtype=torch.float16, 
                add_watermarker=False, 
                safety_checker=None  # Disable safety checker for NSFW content
        )
        pipe = pipe.to("cpu")
    return pipe

def generate_sprite(prompt, filename, seed):

    generator = torch.Generator(device=device).manual_seed(seed)

    load_pipeline()

    # Avoid extremely long prompts that exceed the text encoder's limit
    prompt = _truncate_prompt(prompt)

    image = pipe(
        prompt,
        negative_prompt=NEGATIVE_PROMPT,
        width=WIDTH,
        height=HEIGHT,
        num_inference_steps=NUM_INFERENCE_STEPS,
        guidance_scale=5,
        generator=generator,
    ).images[0]

    image.save(f"assets/{filename}")

def generate_next_sprite(prompt, filename, seed,strength=0.55, init_sprite="toru_idle"):

    generator = torch.Generator(device=device).manual_seed(seed)

    init_image = Image.open(f"assets/{init_sprite}.png").convert("RGB")   

    load_pipeline()

    prompt = _truncate_prompt(prompt)

    image = pipe(
        prompt=prompt,
        negative_prompt=NEGATIVE_PROMPT,
        image=init_image,
        width=WIDTH,
        height=HEIGHT,    
        strength=strength, # how much to change the original (0.8 = mostly new, 0.2 = mostly same)   
        num_inference_steps=NUM_INFERENCE_STEPS,
        guidance_scale=5,
        generator=generator,
    ).images[0]

    image.save(f"assets/{filename}")

def generate_sprite_base_on(prompt, filename, base_sprite, seed):

    generator = torch.Generator(device=device).manual_seed(seed)

    init_image = Image.open(f"assets/{base_sprite}").convert("RGB")   

    load_pipeline()

    prompt = _truncate_prompt(prompt)

    image = pipe(
        prompt=prompt,
        negative_prompt=NEGATIVE_PROMPT,
        image=init_image,
        width=WIDTH,
        height=HEIGHT,
        strength=0.55, # how much to change the original (0.8 = mostly new, 0.2 = mostly same)
        num_inference_steps=NUM_INFERENCE_STEPS,
        guidance_scale=5,
        generator=generator,
    ).images[0]

    image.save(f"assets/{filename}")

def generate_motion_frames(description, base_seed=123456):

    os.makedirs("frames", exist_ok=True)
    load_pipeline()
    base_prompt = get_base_prompt(description) + ", dynamic pose, motion blur"
    base_prompt = _truncate_prompt(base_prompt)

    for i in range(6):  # 6 keyframes

        seed = base_seed + i
        generator = torch.Generator(device=device).manual_seed(seed)

        image = pipe(
            base_prompt,
            negative_prompt=NEGATIVE_PROMPT,
            width=WIDTH,
            height=HEIGHT,
            num_inference_steps=NUM_INFERENCE_STEPS,
            guidance_scale=7,
            generator=generator
        ).images[0]

        image.save(f"frames/frame_{i}.png")

    print("Keyframes generated.")


def get_base_prompt(description):
    description = _truncate_prompt(description)

    return (
        "1girl, upper body, nsfw, looking like for hentai" +
        "same character, consistent face, same proportions, "
        f"{description}, masterpiece, best quality"
    )

def get_base_prompt_for_motion():
    return (
        "1girl, upper body, nsfw, looking like for hentai" +
        "same character, consistent face, same proportions, "
        ", masterpiece, best quality"
    )


def generate_toru_sprites(description):    

    # 🔒 Fixed seed for identity
    base_seed = random.randint(0, 999999999)  

    # 🎨 Core identity prompt (DO NOT CHANGE STRUCTURE)
    base_prompt = get_base_prompt(description)    

    if not os.path.exists("assets/toru_idle.png"):
        generate_sprite(
            base_prompt,
            "toru_idle.png",
            base_seed
        )
   
    if not os.path.exists("assets/toru_talk_A.png"):
        generate_next_sprite(
            get_base_prompt_for_motion() + ", mouth wide open, saying ah",
            "toru_talk_A.png",
            base_seed
        )

    if not os.path.exists("assets/toru_talk_E.png"):
        generate_next_sprite(
            get_base_prompt_for_motion() + ", wide horizontal mouth, saying EE",
            "toru_talk_E.png",
            base_seed
        )
    
    if not os.path.exists("assets/toru_talk_O.png"):
        generate_next_sprite(
            get_base_prompt_for_motion() + ", round mouth, saying oh",
            "toru_talk_O.png",
            base_seed
        )
    
    if not os.path.exists("assets/toru_talk_U.png"):
        generate_next_sprite(
            get_base_prompt_for_motion() + ", small rounded mouth, saying oo",
            "toru_talk_U.png",
            base_seed
        )

    if not os.path.exists("assets/toru_blink_closed.png"):
        generate_next_sprite(
            get_base_prompt_for_motion() + ", closed eyes",
            "toru_blink_closed.png",
            base_seed
        )
    
    if not os.path.exists("assets/toru_blink_half.png"):
        generate_next_sprite(
            get_base_prompt_for_motion() + ", half closed eyes",
            "toru_blink_half.png",
            base_seed
        )


def generate_image_from_prompt(prompt: str) -> int:
    """Generate a single image from an arbitrary prompt and return its ID.

    The image is saved as assets/generated/img_<id>.png and the numeric
    <id> is returned so callers (and the API) can reference it.
    """

    load_pipeline()

    # Truncate overly long prompts to stay within the text encoder limit
    prompt = _truncate_prompt(prompt)

    seed = random.randint(0, 999999999)
    generator = torch.Generator(device=device).manual_seed(seed)

    image_id = _next_generated_image_id()
    generated_dir = os.path.join("assets", "generated")
    filename = os.path.join(generated_dir, f"img_{image_id}.png")

    image = pipe(
        prompt,
        negative_prompt=NEGATIVE_PROMPT,
        width=WIDTH,
        height=HEIGHT,
        num_inference_steps=NUM_INFERENCE_STEPS,
        guidance_scale=5,
        generator=generator,
    ).images[0]

    image.save(filename)

    return {"image_id": image_id, "seed": seed}