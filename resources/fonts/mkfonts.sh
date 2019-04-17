#!/bin/bash

# FontBM is available at https://github.com/vladimirgamalyan/fontbm

wget -c https://www.wfonts.com/download/data/2016/05/06/doom/doom.ttf

# Font with red background for digits
fontbm --font-file doom.ttf --output doom_size10 --font-size 10 --color 170,170,170 --data-format txt --chars 32-121 --include-kerning-pairs

# Font with white background for text
for size in 10 12 14 16 20 24
do
    fontbm --font-file doom.ttf --output doom_size${size} --font-size ${size} --color 255,0,0 --data-format txt --chars 32-121 --include-kerning-pairs
    mv doom_size${size}_0.png doom_size${size}.png
    sed -i -s 's,_0.png,\.png,g' doom_size${size}.fnt
done
