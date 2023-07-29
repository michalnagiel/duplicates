#!/bin/bash

touch /tmp/duplicates-tmp

findDuplicates () {
	if [ -z "$DIRECTORY" ]; then
		DIRECTORY="$(pwd)"
	fi
	if [ -z "$DUPLICATES" ]; then
		DUPLICATES="$(find "$DIRECTORY" ! -empty -type f -exec sha3sum {} + | sort | uniq -w56 -D)"
	fi
	echo "$DUPLICATES" > /tmp/duplicates-tmp
} #creating list of duplicated files and savind it in /tmp/duplicates-tmp

sortDuplicatesBySize () {
	while IFS= read -r line; do
		hash=$(echo "$line" | cut -c -56)
		file=$(echo "$(echo "$line" | cut -c 59-)")
		echo $(stat -c %s "$file") "$hash" "$file" 					#adding size of a file on the begging of each line
	done |
	sort -t " " -k 1 -g -r |										#sorting numbers from the first column descending
 	awk -F " " '{for (i=2; i<NF; i++) printf $i " "; print $NF}' |	#printing every column but the first one (it makes possible to manage directories with spaces)
 	uniq -w56 --all-repeated=separate |								#separate groups of files with the same hash by an empty line
 	cut -c 58-														#remove hash
}

addMetadata () {
	while IFS= read -r line; do
		if [ -n "$line" ]; then
       		echo $(stat -c %s "$line") $(echo $(stat -c %w "$line") | cut -c -19) "$line"	#add size and creation date of the file
		else
			echo ""
		fi
   done
}

sortByTimeOfCreation () {
	awk -v RS= -v cmd=sort '{print | cmd; close(cmd); print ""}'	#sort files in group by a creation date
}

countDuplicates () {
	findDuplicates
	cat /tmp/duplicates-tmp | uniq -w56 -d | wc -l
}

renderListOfDuplicates () {
	findDuplicates
	if [ ! -z "$DUPLICATES" ]; then
		cat /tmp/duplicates-tmp | sortDuplicatesBySize | addMetadata | sortByTimeOfCreation
	fi
}

createListOfDuplicatedFiles () {
	echo "$(echo "$(renderListOfDuplicates)" |
	awk 'BEGIN{ RS="\n\n" } { sub(/[^\n]*\n/, ""); print }' |		#delete first line of each paragraph
	awk -F " " '{for (i=4; i<NF; i++) printf $i " "; print $NF}')"	#delete columns that contain metadata
}

remove () {
	echo "Duplikaty przeznaczone do usunięcia:"
	echo "$(createListOfDuplicatedFiles)"
	echo "Ta operacja jest nieodwracalna. Czy jesteś pewny/a, że chcesz usunąć powyższe pliki? T/n"
	read CONFIRMATION
	if [ $CONFIRMATION = "T" ]; then
		createListOfDuplicatedFiles |
		while IFS= read -r line; do
			rm "$line"
			echo "Usunięto:" "$line"
   		done
	fi
}

showVersion () {
	echo "duplicates v. 1.0"
	echo "Copyright (c) Michał Nagiel"
	echo "License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>."
}

showHelp () {
	echo "Komenda: duplicates [opcje]"
	echo ""
	echo "Opcje:"
	echo "-d 'katalog'			wybierz katalog"
	echo "-l 				stwórz listę duplikatów"
	echo "-c 				wyświetl liczbę plików z duplikatami"
	echo "-v 				pokaż informacje o wersji"
	echo "-h 				pomoc"
	echo "-r				usuń duplikaty"
}

while getopts ':hv' OPTION; do
  case "$OPTION" in
    h)
		showHelp ;;
	v)
		showVersion ;;
  esac
done

OPTIND=1

while getopts ':d:' OPTION; do
  case "$OPTION" in
    d)
		DIRECTORY="$OPTARG"
  esac
done

OPTIND=1

while getopts 'd:lcrvh' OPTION; do
  case "$OPTION" in
	l)
		echo "$(renderListOfDuplicates)" ;;
	c) 
		echo $(countDuplicates) ;;
	r)	
		remove ;;
  esac
done

rm /tmp/duplicates-tmp