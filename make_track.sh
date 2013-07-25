#!/bin/bash

export DESC_DIR=mp3/

source $1

export TMP_DIR_PREFIX=/tmp
export SOX=/opt/local/bin/sox
export BC=/usr/bin/bc
export SCALE=17
export LAME=/opt/local/bin/lame

#export SOX_OPTS="−−multi-threaded −−norm"


function glue_and_trim {
#echo " ==glue_and_trim =="
TMP_DIR=$3
SRC_FILE=$4
DEST_FILE=$5
PARAM=
for k in `seq $1`
do
PARAM="$PARAM $SRC_FILE"
done

$SOX $PARAM "$TMP_DIR/p_$DEST_FILE"
$SOX  "$TMP_DIR/p_$DEST_FILE"  "$TMP_DIR/$DEST_FILE" trim 0 $2
rm "$TMP_DIR/p_$DEST_FILE"
}

function pann_and_volume {
#echo " == pann_and_volume =="
TMP_DIR=$3
SRC_FILE=$4
$SOX "$TMP_DIR/$SRC_FILE" -c 1 "$TMP_DIR/1_$SRC_FILE" remix 1 0
$SOX "$TMP_DIR/$SRC_FILE" -c 1 "$TMP_DIR/2_$SRC_FILE" remix 0 1
$SOX -v $1 "$TMP_DIR/1_$SRC_FILE" "$TMP_DIR/1v_$SRC_FILE"
$SOX -v $2 "$TMP_DIR/2_$SRC_FILE" "$TMP_DIR/2v_$SRC_FILE"
$SOX -M "$TMP_DIR/1v_$SRC_FILE" "$TMP_DIR/2v_$SRC_FILE" "$TMP_DIR/$SRC_FILE"
rm "$TMP_DIR/1_$SRC_FILE" "$TMP_DIR/2_$SRC_FILE" "$TMP_DIR/1v_$SRC_FILE" "$TMP_DIR/2v_$SRC_FILE"
}

function add_silence {
DEST_FILE=$1
ADD_TYPE=$3
$SOX -n -r 44100 -c 2 "$TMP_DIR/silence.wav" trim 0.0 $2
if [ $ADD_TYPE -eq 1 ]
then
 $SOX "$TMP_DIR/$DEST_FILE" "$TMP_DIR/silence.wav" "$TMP_DIR/tmp_$DEST_FILE"
 mv "$TMP_DIR/tmp_$DEST_FILE" "$TMP_DIR/$DEST_FILE"
else
 mv "$TMP_DIR/silence.wav" "$TMP_DIR/$DEST_FILE"
fi
}

function clean_all {
rm -r $TMP_DIR_PREFIX/$MIX_NAME/*.*
rmdir $TMP_DIR_PREFIX/$MIX_NAME
}

function add_piece {
DEST_FILE=$1
SRC_FILE=$2
OFFSET=$3
LENGHT=$4
ADD_TYPE=$5
 $SOX  "$TMP_DIR/$SRC_FILE"  "$TMP_DIR/p_$DEST_FILE" trim $OFFSET $LENGHT
if [ $ADD_TYPE -eq 1 ]
then
 $SOX "$TMP_DIR/$DEST_FILE" "$TMP_DIR/p_$DEST_FILE" "$TMP_DIR/tmp_$DEST_FILE"
 mv "$TMP_DIR/tmp_$DEST_FILE" "$TMP_DIR/$DEST_FILE"
else
 mv "$TMP_DIR/p_$DEST_FILE" "$TMP_DIR/$DEST_FILE"
fi
}

if [ -e "$TMP_DIR_PREFIX/$MIX_NAME" ]
then
echo "directory $TMP_DIR_PREFIX/$MIX_NAME exists"
exit 1
fi
mkdir "$TMP_DIR_PREFIX/$MIX_NAME"

MIXTRAX=

for i in `seq $TRACK_NUMBER`
do
eval TRACK_SRC=\$$(echo "TRACK_"$i"_SRC")
eval TRACK_VOLUME=\$$(echo "TRACK_"$i"_VOLUME")
eval TRACK_PANNING=\$$(echo "TRACK_"$i"_PANNING")
TRACK_CELLS=$(echo "TRACK_"$i"_CELLS[*]")

if [ ! -f $TRACK_SRC ]
then
echo "file $TRACK_SRC not exists"
clean_all
exit 2
fi

#echo  $TRACK_SRC
#echo  $TRACK_VOLUME
#echo  $TRACK_PANNING

glue_and_trim $CELL_COUNT $TOTAL_TIME "$TMP_DIR_PREFIX/$MIX_NAME" $TRACK_SRC "$i.wav" 

LEFT_VOLUME=$TRACK_VOLUME
RIGHT_VOLUME=$TRACK_VOLUME
if [ $TRACK_PANNING -lt 0 ]
then
RIGHT_VOLUME=`echo "scale=$SCALE; $RIGHT_VOLUME*(1+$TRACK_PANNING)" | $BC`
else
LEFT_VOLUME=`echo "scale=$SCALE; $LEFT_VOLUME*(1-$TRACK_PANNING)" | $BC`
fi
pann_and_volume $LEFT_VOLUME $RIGHT_VOLUME "$TMP_DIR_PREFIX/$MIX_NAME" "$i.wav"


PREV_J=0
ADD_TYPE=0
SILENCE=1
#echo  ${!TRACK_CELLS}
for j in ${!TRACK_CELLS}
do
if [ $j -ne 0 ]
then
  if [ $SILENCE -eq 1 ]
    then
	LENGHT=`echo "scale=$SCALE; ($j-$PREV_J)*$CELL_TIME" | $BC`
        add_silence "prc_$i.wav" $LENGHT $ADD_TYPE
  else
      OFFSET=`echo "scale=$SCALE; ($PREV_J)*$CELL_TIME" | $BC`
      LENGHT=`echo "scale=$SCALE; ($j-$PREV_J)*$CELL_TIME" | $BC`
      add_piece "prc_$i.wav" "$i.wav" $OFFSET $LENGHT $ADD_TYPE
  fi
ADD_TYPE=1
fi
PREV_J=$j
if [ $SILENCE -eq 1 ]
then
  SILENCE=0
else
  SILENCE=1
fi
done
MIXTRAX="$MIXTRAX $TMP_DIR_PREFIX/$MIX_NAME/prc_$i.wav"
done
$SOX -m $MIXTRAX  "$TMP_DIR_PREFIX/$MIX_NAME/$MIX_NAME.wav"
$SOX "$TMP_DIR_PREFIX/$MIX_NAME/$MIX_NAME.wav" -n stat -v &> "$TMP_DIR_PREFIX/$MIX_NAME/max_volume.txt"
MAX_VOLUME=`cat $TMP_DIR_PREFIX/$MIX_NAME/max_volume.txt`
$SOX -v $MAX_VOLUME "$TMP_DIR_PREFIX/$MIX_NAME/$MIX_NAME.wav" "$TMP_DIR_PREFIX/$MIX_NAME/max_$MIX_NAME.wav"
mv "$TMP_DIR_PREFIX/$MIX_NAME/max_$MIX_NAME.wav" "$TMP_DIR_PREFIX/$MIX_NAME/$MIX_NAME.wav"
$LAME --silent "$TMP_DIR_PREFIX/$MIX_NAME/$MIX_NAME.wav" "$TMP_DIR_PREFIX/$MIX_NAME/$MIX_NAME.mp3"
mv "$TMP_DIR_PREFIX/$MIX_NAME/$MIX_NAME.mp3" $DESC_DIR
clean_all
