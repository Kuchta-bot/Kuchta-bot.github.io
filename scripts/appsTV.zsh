appGet() {
  local customer="$1"           # např.: orange
  local version="$2"            # např.: 13.5.0
  local env="$3"                # production | stage
  local out_dir="${4:-$HOME/Downloads/app/${customer}}"
  local tz="${5:-Europe/Prague}"
  mkdir -p "$out_dir" || return 1
  command -v curl >/dev/null || { echo "Je potřeba mít nainstalovaný curl"; return 1; }

  local base="https://files.nangu.tv/apps3/${customer}"

  # ---- HTTP helper (HEAD + follow redirects) ----
  http_200() { local c; c=$(curl -sIL -o /dev/null -w "%{http_code}" "$1" || true); [[ "$c" == "200" ]]; }

  # ---------- Společné pomocné funkce ----------
  # stáhne HTML index adresáře
  fetch_index() { curl -fsL "$1" || true; }

  # z HTML indexu vybere řádky obsahující "default-tv.########/" a vrátí největší ########
  latest_build_from_default_tv_index() {
    local html="$1"
    echo "$html" | grep -Eo 'default-tv\.[0-9]{8}/' | grep -Eo '[0-9]{8}' | sort -nr | head -n1
  }

  # vrátí seznam všech .apk z HTML (po jednom na řádek)
  list_apk_from_html() {
    local html="$1"
    echo "$html" | grep -Eo '[^" >]+\.apk' | sort -u
  }

  # z názvu vytáhne build (8 číslic) na konci před ".apk" – bez GNU look-ahead
  extract_build() {
    # pokud řetězec nekončí na ".apk" s 8 číslicemi, vrátí prázdno
    echo "$1" | sed -E 's/.*([0-9]{8})\.apk$/\1/;t;d'
  }

  # ze STDIN vezme seznam APK, vytiskne "BUILD NÁZEV_APK" s největším buildem
pick_latest_apk_name_and_build_from_list() {
  awk '
    {
      name=$0
      # BSD/POSIX awk: bez třetího argumentu; použijeme RSTART/RLENGTH
      if (match(name, /[0-9]{8}\.apk$/)) {
        b = substr(name, RSTART, 8)
        print b " " name
      }
    }
  ' | sort -nr | head -n1
}

  # ---------- ANDROID: načtení indexu (bez mapfile) ----------
  local and_idx_url="$base/NGA/$version/$env/"
  local and_idx_html; and_idx_html="$(fetch_index "$and_idx_url")"
  local AND_APK_LIST; AND_APK_LIST="$(list_apk_from_html "$and_idx_html")"

  # nejnovější APK napříč všemi (standard)
  local and_best_line and_build and_name
  and_best_line="$(printf "%s\n" "$AND_APK_LIST" | pick_latest_apk_name_and_build_from_list)"
  if [[ -n "$and_best_line" ]]; then
    and_build="${and_best_line%% *}"
    and_name="${and_best_line#* }"
  else
    and_build=""; and_name=""
  fi

  # pokud customer == orange, připravíme i Cherry
  local and_cherry_build="" and_cherry_name=""
  if [[ "$customer" == "orange" && -n "$AND_APK_LIST" ]]; then
    # 1) pokus Cherry se stejným buildem jako standard
    and_cherry_name="$(printf "%s\n" "$AND_APK_LIST" | grep -Ei 'cherry' | grep -F ".$and_build.apk" | head -n1 || true)"
    if [[ -n "$and_cherry_name" ]]; then
      and_cherry_build="$and_build"
    else
      # 2) vezmi nejnovější Cherry podle buildu
      local cherry_best
      cherry_best="$(printf "%s\n" "$AND_APK_LIST" | grep -Ei 'cherry' | pick_latest_apk_name_and_build_from_list || true)"
      if [[ -n "$cherry_best" ]]; then
        and_cherry_build="${cherry_best%% *}"
        and_cherry_name="${cherry_best#* }"
      fi
    fi
  fi

  # ---------- TIZEN: poslední build pro build.zip ----------
  local tiz_idx_url="$base/NGT/$version/$env/"
  local tiz_idx_html; tiz_idx_html="$(fetch_index "$tiz_idx_url")"
  local tiz_build; tiz_build="$(latest_build_from_default_tv_index "$tiz_idx_html")"

  # ---------- LG: poslední build pro default-tv.<BUILD>/ ----------
  local lg_idx_url="$base/NGLG/$version/$env/"
  local lg_idx_html; lg_idx_html="$(fetch_index "$lg_idx_url")"
  local lg_build; lg_build="$(latest_build_from_default_tv_index "$lg_idx_html")"

  # fallback: pokud některá platforma nemá build, vezmeme nejnovější známý z ostatních
  latest_known_build() {
    printf "%s\n%s\n%s\n%s\n" "$and_build" "$and_cherry_build" "$tiz_build" "$lg_build" | grep -E '^[0-9]{8}$' | sort -nr | head -n1
  }
  [[ -z "$tiz_build" ]] && tiz_build="$(latest_known_build)"
  [[ -z "$lg_build"  ]] && lg_build="$(latest_known_build)"

  echo ">> Stahuji do: $out_dir"
  echo "   Zákazník: $customer | Verze: $version | Prostředí: $env"
  echo "   Android build: ${and_build:-neznámý}${and_cherry_build:+ | Cherry: $and_cherry_build} | Tizen build: ${tiz_build:-neznámý} | LG build: ${lg_build:-neznámý}"
  echo

  # ---------- statusy ----------
  local android_status="❌"
  local android_cherry_status=""   # zobrazíme jen pro orange
  local tizen_status="❌"
  local lg_status="❌"

  # ---------- ANDROID (standard) ----------
  if [[ -n "$and_name" && -n "$and_build" ]]; then
    local url_apk="$and_idx_url$and_name"
    local file_apk="$out_dir/Android_${customer}_${version}_${and_build}.apk"
    echo "-> Android (standard): $url_apk"
    if http_200 "$url_apk" && curl -fL --retry 3 --retry-delay 2 --continue-at - --output "$file_apk" "$url_apk"; then
      android_status="✅"
    fi
  fi

  # ---------- ANDROID (Cherry) – jen pro orange ----------
  if [[ "$customer" == "orange" ]]; then
    android_cherry_status="❌"
    if [[ -n "$and_cherry_name" && -n "$and_cherry_build" ]]; then
      local url_apk_ch="$and_idx_url$and_cherry_name"
      local file_apk_ch="$out_dir/AndroidCherry_${customer}_${version}_${and_cherry_build}.apk"
      echo "-> Android (Cherry): $url_apk_ch"
      if http_200 "$url_apk_ch" && curl -fL --retry 3 --retry-delay 2 --continue-at - --output "$file_apk_ch" "$url_apk_ch"; then
        android_cherry_status="✅"
      fi
    fi
  fi

  # ---------- TIZEN ----------
  if [[ -n "$tiz_build" ]]; then
    local url_tizen="$base/NGT/$version/$env/default-tv.$tiz_build/build.zip"
    local file_tizen="$out_dir/Tizen_${customer}_${version}_${tiz_build}.zip"
    echo "-> Tizen: $url_tizen"
    if http_200 "$url_tizen" && curl -fL --retry 3 --retry-delay 2 --continue-at - --output "$file_tizen" "$url_tizen"; then
      tizen_status="✅"
    fi
  fi

  # ---------- LG (jen FHD z posledního buildu) ----------
  if [[ -n "$lg_build" ]]; then
    local lg_dir="$base/NGLG/$version/$env/default-tv.$lg_build/"
    echo "-> LG adresář: $lg_dir"
    local lg_fhd_name
    lg_fhd_name="$(fetch_index "$lg_dir" | grep -Eo '[^" >]*FHD\.ipk' | sort -u | head -n1 || true)"
    if [[ -n "$lg_fhd_name" ]]; then
      local url_lg="$lg_dir$lg_fhd_name"
      local file_lg="$out_dir/LG_${customer}_${version}_${lg_build}_FHD.ipk"
      echo "   LG FHD: $url_lg"
      if http_200 "$url_lg" && curl -fL --retry 3 --retry-delay 2 --continue-at - --output "$file_lg" "$url_lg"; then
        lg_status="✅"
      fi
    fi
  fi

  # ---------- Finální přehled ----------
  echo
  echo "Android (standard) - $android_status"
  if [[ "$customer" == "orange" ]]; then
    echo "Android (Cherry)   - $android_cherry_status"
  fi
  echo "Tizen              - $tizen_status"
  echo "LG                 - $lg_status"
}
