#!/bin/bash

function search_for_prohibited_files () {
	
	#rm possible_prohibited_files.txt

	printf "\nPossible prohibited images:\n\n" >> possible_prohibited_files.txt

	find /home  -type f -name "*.jpg" >> possible_prohibited_files.txt
	find /home  -type f -name "*.jpeg" >> possible_prohibited_files.txt
	find /home -type f -name "*.gif" >> possible_prohibited_files.txt
	find /home -type f -name "*.png" >> possible_prohibited_files.txt
	find /home -type f -name "*.bmp" >> possible_prohibited_files.txt
	find /home -type f -name "*.webp" >> possible_prohibited_files.txt

	printf "\nPossible prohibited videos:\n\n" >> possible_prohibited_files.txt

	find /home -type f -name "*.mp4" >> possible_prohibited_files.txt
	find /home -type f -name "*.mov" >> possible_prohibited_files.txt
	find /home -type f -name "*.wmv" >> possible_prohibited_files.txt
	find /home -type f -name "*.avi" >> possible_prohibited_files.txt
	find /home -type f -name "*.mkv" >> possible_prohibited_files.txt

	printf "\nPossible prohibited music files:\n\n" >> possible_prohibited_files.txt

	find /home -type f -name "*.mp3" >> possible_prohibited_files.txt
	find /home -type f -name "*.aac" >> possible_prohibited_files.txt
	find /home -type f -name "*.ogg" >> possible_prohibited_files.txt
	find /home -type f -name "*.flac" >> possible_prohibited_files.txt
	find /home -type f -name "*.alac" >> possible_prohibited_files.txt
	find /home -type f -name "*.wav" >> possible_prohibited_files.txt

	printf "\nPossible prohibited archived files:\n\n" >> possible_prohibited_files.txt

	find /home -type f -name "*.zip" >> possible_prohibited_files.txt
	find /home -type f -name "*.7z" >> possible_prohibited_files.txt
	find /home -type f -name "*.tar" >> possible_prohibited_files.txt
	find /home -type f -name "*.tar.gz" >> possible_prohibited_files.txt
	find /home -type f -name "*.tgz" >> possible_prohibited_files.txt
	find /home -type f -name "*.gz" >> possible_prohibited_files.txt
	find /home -type f -name "*.deb" >> possible_prohibited_files.txt
}

search_for_prohibited_files