#!/bin/bash

set -xe

pushd /mnt/extracted
	if [ "${ENGLISH_COMPATIBLE}" = "1" ]; then
		OLD_LANG=${LANG}
		export LANG=it_IT.UTF-8
	fi;

	if [ ! -f "wiki_it.txt" ]; then
		curl -sSL https://github.com/MozillaItalia/DeepSpeech-Italian-Model/releases/download/lm-0.1/wiki.txt.xz | pixz -d > wiki_it.txt
	fi;

	if [ "${ENGLISH_COMPATIBLE}" = "1" ]; then
		mv wiki_it.txt wiki_it_accents.txt
		# Locally force LANG= to make iconv happy and avoid errors like:
		# iconv: illegal input sequence at position 4468
		# Also required locales and locales-all to be installed
		head -n 5 wiki_it_accents.txt
		iconv -f UTF-8 -t ASCII//TRANSLIT//IGNORE < wiki_it_accents.txt > wiki_it.txt
		head -n 5 wiki_it.txt
		> wiki_it_accents.txt
	fi;

	if [ ! -f "/mnt/lm/scorer" ]; then
		pushd $DS_DIR/data/lm
			top_k=500000
			if [ "${FAST_TRAIN}" = 1 ]; then
				head -10000 /mnt/extracted/wiki_it.txt > /mnt/extracted/sources_lm.txt
				top_k=500
			else
				mv /mnt/extracted/wiki_it.txt /mnt/extracted/sources_lm.txt
				touch /mnt/extracted/wiki_it.txt
			fi

			python generate_lm.py --input_txt "/mnt/extracted/sources_lm.txt" --output_dir "/mnt/lm" \
				--top_k $top_k --kenlm_bins "$DS_DIR/native_client/kenlm/build/bin/" \
				--arpa_order 5 --max_arpa_memory "85%" --arpa_prune "0|0|1" \
				--binary_a_bits 255 --binary_q_bits 8 --binary_type trie

			python generate_package.py --alphabet /mnt/models/alphabet.txt \
			  --lm "/mnt/lm/lm.binary" \
			  --vocab "/mnt/lm/vocab-"$top_k".txt" \
			  --package "/mnt/lm/scorer" \
			  --default_alpha 0.931289039105002 \
			  --default_beta 1.1834137581510284
	fi;

	if [ "${ENGLISH_COMPATIBLE}" = "1" ]; then
		export LANG=${OLD_LANG}
	fi;
popd
