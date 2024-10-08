#!/bin/bash
vsim -c -do run.do

rm hex.txt softfloat_output.txt flags.txt

# Lettura dei giusti campi da data_in.hex
line_number=1
op=fadd64
line2="" line3=""
echo "Performing Softfloat calculations..."
while IFS= read -r line; do
  if (( line_number % 3 == 1 )); then
    line2=$line
  elif (( line_number % 3 == 2 )); then
    line3=$line
	../generic_float_calculator-main/build/reference_model $op $line2 | awk -F'[()]' '{if (NF>1) print $4}' >> flags.txt
#	../generic_float_calculator-main/build/reference_model $op $line3 $line2 >> flags.txt
	../generic_float_calculator-main/build/reference_model $op $line2 | grep -oP '0x[0-9a-fA-F]+' >> hex.txt
  fi
  ((line_number++))
done < "data_in.hex"

line_number=1
line=""
while IFS= read -r line; do
  if (( line_number % 2 == 0 )); then
    line2=$line
        echo $line2 >> softfloat_output.txt
  fi
  ((line_number++))
done < "hex.txt"
