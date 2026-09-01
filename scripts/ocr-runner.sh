#!/usr/bin/env bash
set -u

image=${1:-}
requested=${2:-auto}

if [[ -z "$image" || ! -f "$image" ]]; then
  printf 'OCR input image is missing\n' >&2
  exit 2
fi
if ! command -v tesseract >/dev/null 2>&1; then
  printf 'tesseract is not installed\n' >&2
  exit 127
fi

mapfile -t available < <(tesseract --list-langs 2>/dev/null | tail -n +2 | sed '/^[[:space:]]*$/d')
if ((${#available[@]} == 0)); then
  printf 'No Tesseract language data is installed\n' >&2
  exit 3
fi

has_lang() {
  local wanted=$1 lang
  for lang in "${available[@]}"; do
    [[ "$lang" == "$wanted" ]] && return 0
  done
  return 1
}

locale_lang() {
  local locale=${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}
  case "$locale" in
    ja*|JA*) printf 'jpn' ;;
    ru*|RU*) printf 'rus' ;;
    zh_TW*|zh_HK*|zh_MO*|ZH_TW*|ZH_HK*|ZH_MO*) printf 'chi_tra' ;;
    zh*|ZH*) printf 'chi_sim' ;;
    es*|ES*) printf 'spa' ;;
    *) printf 'eng' ;;
  esac
}

auto_mode=false
if [[ "$requested" == auto || -z "$requested" ]]; then
  auto_mode=true
  requested=$(locale_lang)
fi

IFS='+' read -r -a wanted <<< "$requested"
selected=()
missing=()
for lang in "${wanted[@]}"; do
  if has_lang "$lang"; then
    selected+=("$lang")
  else
    missing+=("$lang")
  fi
done

# Auto should remain useful on systems whose locale language pack was removed.
# An explicit choice is different: silently recognizing Japanese as English is
# worse than a clear error because the clipboard would contain plausible junk.
if [[ "$auto_mode" == true && ${#selected[@]} == 0 ]]; then
  if has_lang eng; then
    selected=(eng)
  else
    for lang in "${available[@]}"; do
      [[ "$lang" == osd ]] && continue
      selected=("$lang")
      break
    done
  fi
elif [[ "$auto_mode" == false && ${#missing[@]} -gt 0 ]]; then
  printf 'Tesseract language data is not installed: %s
' "$(IFS=+; printf '%s' "${missing[*]}")" >&2
  exit 4
fi

if ((${#selected[@]} == 0)); then
  printf 'No usable Tesseract language data is installed\n' >&2
  exit 3
fi

langs=$(IFS=+; printf '%s' "${selected[*]}")
exec tesseract "$image" stdout -l "$langs"
