#!/bin/bash -xe
# /home/renderaccount/src
FOLDER=${FOLDER:-/home/mapnikdb}
DB_NAME=${DB_NAME:-osm}
OSMOSIS=${OSMOSIS:-$FOLDER/osmosis.run}
DB_PORT=${DB_PORT:-5433}
TILES_DIR=${TILES_DIR:-/var/lib/tirex/tiles/}
TILES_SOCK=${TILES_SOCK:-/var/lib/tirex/modtile.sock}
OSM_STYLE=${OSM_STYLE:/usr/local/share/osm2pgsql/default.style}

ID=$(date +"%d_%m_%H_%M")
CHANGES_FILE=$FOLDER/changes_$ID.osc.gz
EXPIRED_FILE=$FOLDER/expired_tiles_$ID.list

echo "CURRENT STATE: "
cat "$FOLDER/osmosis-workdir/state.txt"
cp $FOLDER/osmosis-workdir/state.txt $FOLDER/osmosis-workdir/state-old.txt

$OSMOSIS --rri workingDirectory=$FOLDER/osmosis-workdir --simplify-change --write-xml-change $CHANGES_FILE
echo "FUTURE STATE: "
cat "$FOLDER/osmosis-workdir/state.txt"

cp $FOLDER/osmosis-workdir/state.txt $FOLDER/osmosis-workdir/state-new.txt
cp $FOLDER/osmosis-workdir/state-old.txt $FOLDER/osmosis-workdir/state.txt

# -U jenkins
osm2pgsql --append --slim -d $DB_NAME -P $DB_PORT --cache-strategy dense \
	--cache 20000 --number-processes 4 --hstore \
 	--style $OSM_STYLE --multi-geometry \
 	--flat-nodes $FOLDER/flatnodes.bin \
	--expire-tiles 13-18 --expire-output $EXPIRED_FILE $CHANGES_FILE
cp $FOLDER/osmosis-workdir/state-new.txt $FOLDER/osmosis-workdir/state.txt

rm $CHANGES_FILE
gzip $EXPIRED_FILE
gzip -cd $EXPIRED_FILE.gz | render_expired --map=default --socket=$TILES_SOCK --tile-dir=$TILES_DIR --num-threads=4 --touch-from=13 --min-zoom=13
gzip -cd $EXPIRED_FILE.gz | render_expired --map=highres --socket=$TILES_SOCK --tile-dir=$TILES_DIR --num-threads=4 --touch-from=13 --min-zoom=13
# rm $EXPIRED_FILE.gz

echo "STATE COMMIT: "
cat "$FOLDER/osmosis-workdir/state.txt"
