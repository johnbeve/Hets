#!/bin/sh
FILES=`git ls-tree --name-only HEAD *.hs`
echo $FILES | xargs -n 1 $HOME/.cabal/bin/scan -i > /dev/null
echo $FILES | xargs $HOME/.cabal/bin/scan
echo $FILES | xargs $HOME/.cabal/bin/hlint -i "Use camelCase" -i "Use infix" \
    -i "Use >=>" -i "Use first" -i "Use ***" -i "Use second" -i "Use &&&"
