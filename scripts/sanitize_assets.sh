#!/usr/bin/env bash
set -euo pipefail

echo "=== Запуск санации ассетов Xomsky & очистки video-team3 ==="

# --- 1. Удаление забракованных и устаревших файлов (34 шт.) ---

# 1.1. Explorations (альтернативные драфты, брак и устаревшие матрицы иконок - 12 шт.)
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/explorations/khomyak_3d_light_appicon.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/explorations/khomyak_3d_light_mascot.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/explorations/khomyak_alt_identity_appicon.jpg"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/explorations/khomyak_appicon_matrix.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/explorations/khomyak_appicon_option_a_light.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/explorations/khomyak_appicon_option_b_macro.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/explorations/khomyak_appicon_option_d_monolith.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/explorations/khomyak_appicon_pure_nofeet.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/explorations/khomyak_appicon_pure_wave.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/explorations/khomyak_dock_comparison.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/explorations/khomyak_pure_dock_preview.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/explorations/khomyak_pure_hamster_matrix.png"

# 1.2. Renders (устаревшие 2K-рендеры старого позиционирования и черновые генерации - 11 шт.)
# ПРИМЕЧАНИЕ: test_pro_part.png СОХРАНЕН по указанию пользователя ("Нравится, но требует доработки...")
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/renders/caps_lock_macro_3d_1789621047420.jpg"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/renders/chrome_switcher_3d_1789621080890.jpg"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/renders/copy_select_3d_1789621114550.jpg"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/renders/khomyak_dark_studio_hero_1789621064353.jpg"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/renders/toolkit_switcher_3d_1789621097687.jpg"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/renders/pro_caps_hyper_2k.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/renders/pro_chrome_switch_2k.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/renders/pro_copy_select_2k.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/renders/pro_copy_select_silhouettes_2k.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/renders/pro_hero_banner_2k.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/renders/pro_toolkit_switch_2k.png"

# 1.3. Tmp (старые тестовые записи, временные hud и черновые баннеры - 11 шт.)
# ПРИМЕЧАНИЕ: СОХРАНЕНЫ ценные демо:
# - Screen Recording 2026-09-14 at 8.59.07.mov (демо проблемы cmd+tab)
# - hud.mov (демо альтернативного HUD)
# - hud_new.mp4 (демо альтернативного HUD)
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/tmp/Screen Recording 2026-09-11 at 17.04.08.mov"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/tmp/Screen Recording 2026-09-23 at 18.42.00.mov"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/tmp/banner_clean_full.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/tmp/banner_crop.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/tmp/banner_crop_perfect.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/tmp/banner_helvetica_crop.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/tmp/banner_test.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/tmp/banner_test_crop.png"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/tmp/hud.mp4"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/tmp/hud_new_3.mp4"
rm -rf "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/tmp/screens-2"

# --- 2. Перенос в архив ценных референсов (2 шт.) ---
mkdir -p "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/archive"
mv "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/tmp/example_gif.mp4" "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/archive/"
mv "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/tmp/website-examples" "/Users/igorekishev/Igor/igorekishev/mac-productivity-suite/assets/archive/"

# --- 3. Очистка корня video-team3 (14 файлов) ---
mkdir -p "/Users/igorekishev/projects/video-team3/projects/filevine/"
mv "/Users/igorekishev/projects/video-team3/Filevine_Cheat_Sheet_IgorEkishev.pdf" "/Users/igorekishev/projects/video-team3/projects/filevine/"
mv "/Users/igorekishev/projects/video-team3/filevine_cheat_sheet.html" "/Users/igorekishev/projects/video-team3/projects/filevine/"

mkdir -p "/Users/igorekishev/projects/video-team3/scratch/nabokov/"
mv "/Users/igorekishev/projects/video-team3/nabokov_slovo.ru.vtt" "/Users/igorekishev/projects/video-team3/scratch/nabokov/"

mkdir -p "/Users/igorekishev/projects/video-team3/scratch/shoom/"
mv "/Users/igorekishev/projects/video-team3/studio_shoom."* "/Users/igorekishev/projects/video-team3/scratch/shoom/"
mv "/Users/igorekishev/projects/video-team3/shoom_studio_phrase."* "/Users/igorekishev/projects/video-team3/scratch/shoom/"

echo "✅ Санация ассетов успешно завершена! 34 файла удалено, 2 архивировано, корень video-team3 очищен."
