#!/bin/mksh -p

noshow=1

case $1 in
  -show) noshow=0 ; shift
esac

if [ -z "$1" ]
then
  echo "$0 [-tar tarfilename] image"
  exit 255
fi

if [ "$1" == "-tar" -a -n "$2" ]
then
  tarfile=$2
  shift 2
fi

image=$1

tmpdir=$(mktemp -d)

trap 'cd /tmp ; /bin/rm -rf $tmpdir ; exit 0' 0 1 2 3 15

# Extract the requested image
echo Extracting $image... please wait
if [ -n "$tarfile" ]
then
  cat $tarfile
else
  docker save $image
fi | ( cd $tmpdir && tar xf - )

cd $tmpdir || exit

imagelayer=$(echo $image | tr -dc 'a-zA-Z0-9')

# We need a list of layers in the right order
layers=$(jq -r '.[] | .Layers' manifest.json | tr -d ',"[]')
set -- $layers
shift $(( $# - 1 ))
lastlayer=$1

parent=""
for a in $layers
do
  if [[ "$a" == "$lastlayer" ]]
  then
    l=$imagelayer
  else
    l=${a%/layer.tar}
  fi
  echo -n "Checking layer $l: "
  d=$(cat <<-EOC
	{"Layer":{"Name":"$l","Path":"$tmpdir/$a","Format":"Docker"$parent}}
	EOC
  )
  print $d
  r=$(curl --noproxy '*' -s -d"$d" -X POST http://127.0.0.1:6060/v1/layers)
  case $r in
    \{\"Error\"*) echo -- "$r" ;;
              *) echo "OK"
  esac
  parent=",\"ParentName\": \"$l\""
done

if [ $noshow == 0 ]
then
  curl --noproxy '*' -s -X GET http://127.0.0.1:6060/v1/layers/$image?vulnerabilities | jq .
fi

echo
echo
echo
print "Layers loaded: $imagelayer"
