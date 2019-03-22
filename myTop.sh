#!/bin/bash

rm -f ./procs.log 2> /dev/null
rm -f ./procsOrdenados.log 2>/dev/null


#calculamos el uso de la cpu al principio del primer bucle

cpuTotalInicial=$(awk '/cpu/ {print $2+$3+$4+$5+$6+$7+$8}' </proc/stat | head -1)
cpuUsoInicial=$(awk '/cpu/ {print $2+$3+$4}' </proc/stat | head -1)

hercios=$(getconf CLK_TCK)
directorio=$(ls -la /proc | awk '{print $9}' | grep "[0-9]")
totalDir=$(ls -la /proc | awk '{print $9}' | grep "[0-9]" | wc -l)

#Variables para los datos de Memoria

memTotal=$(awk '/MemTotal/ {print $2}' < /proc/meminfo)
memLibre=$(awk '/MemFree/ {print $2}' < /proc/meminfo)
memDisponible=$(awk '/MemAvailable/ {print $2}' </proc/meminfo)
buffer=$(awk '/Buffers/ {print $2}' </proc/meminfo)

#Como existen 2 campos con "cached". elegimos obtener el primer campo que es el que nos interesa
memCache=$(awk '/Cached/ {print $2}' </proc/meminfo | head -1)
cachBuffer=$(($memCache+$buffer))

swapTotal=$(awk '/SwapTotal/ {print $2}' </proc/meminfo)
swapFree=$(awk '/SwapFree/ {print $2}' </proc/meminfo)
swapUse=$(($swapTotal-$swapFree))

memUsada=$(($memTotal-($memLibre+$cachBuffer)))
porcUsada=$(echo "scale = 3; ($memUsada/$memTotal)*100" | bc | awk '{printf "%.2f", $0}')

cont=1


while [ $cont -le $totalDir ];
do
start=$(date +%s.%N)
#Obtenemos el listado de los PID
PID=$(echo $directorio | awk '{print $('$cont')}')	

#Calculamos el uso de CPU por proceso en la primera pasada

modoUser[$cont]=$(awk '{print $14}' 2>/dev/null </proc/$PID/stat)
modoNucleo[$cont]=$(awk '{print $15}' 2>/dev/null </proc/$PID/stat)

compUser=${modoUser[$cont]}
compNucleo=${modoNucleo[$cont]}

if [ -z $compUser ] || [ -z $compNucleo ];
then
echo 2>/dev/null
else
tiempoTotal1[$cont]=$((${modoUser[$cont]}+${modoNucleo[$cont]}))
fi


let cont=cont+1
done

sleep 1

#calculamos el uso de la cpu al principio del segundo bucle

cpuTotalFinal=$(awk '/cpu/ {print $2+$3+$4+$5+$6+$7+$8}' </proc/stat | head -1)
cpuUsoFinal=$(awk '/cpu/ {print $2+$3+$4}' </proc/stat | head -1)

porcCPU=$(echo "scale=10; (($cpuUsoFinal-$cpuUsoInicial)/($cpuTotalFinal-$cpuTotalInicial))*100" | bc | awk '{printf "%.2f", $0}')


#=========SEGUNDA VUELTA=========
cont=1

while [ $cont -le $totalDir ];
do

#Obtenemos el listado de los PID
PID=$(echo $directorio | awk '{print $('$cont')}')	

#Obtenemos el usuario que ejecuta los procesos
userID=$(awk '/Uid/ {print $2}' 2>/dev/null </proc/$PID/status)
user=$(getent passwd $userID | cut -d: -f1)

#Obtencion de la prioridad del proceso
prior=$(awk '{print $18}' 2>/dev/null </proc/$PID/stat)

#Obtencion del estado del proceso
status=$(awk '{print $3}' 2>/dev/null </proc/$PID/stat)

#Obtencion de la Memoria Virtual de cada proceso
const=1024
memVir=$(awk '{print $23}' 2>/dev/null </proc/$PID/stat)

if [ -z $memVir ] || [ $memVir -eq 0 ];
then
echo 2>/dev/null
else
memVirtual=$(($memVir/$const))
fi

#Obtencion del nombre del proceso
command=$(awk '{print $2}' 2>/dev/null </proc/$PID/stat | sed 's/^.\|.$//g')

#Obtencion del %mem
rss=$(awk '/VmRSS/ {print $2}' 2>/dev/null </proc/$PID/status)

if [ -z $rss ] || [ $rss -eq 0 ]; then
pMem=0
else
pMem=$(echo "scale = 3; ($rss/$memTotal)*100" | bc 2> /dev/null | awk '{printf "%.1f", $0}')
fi

#Calculamos el tiempo de ejecucion del proceso
time=$(awk '{print $22}' 2>/dev/null </proc/$PID/stat)
	
if [ -z $time ];
then
time=0
fi
	
uptime=$(awk '{print $1}' < /proc/uptime)
secs=$((${uptime%.*}-$time/$hercios))
totalTime=$(printf '%dh:%dm:%ds\n' $(($secs/3600)) $(($secs%3600/60)) $(($secs%60)))

#Calculamos el modo usuario y modo nucleo en la segunda pasada

modoUser[$cont]=$(awk '{print $14}' 2>/dev/null </proc/$PID/stat)
modoNucleo[$cont]=$(awk '{print $15}' 2>/dev/null </proc/$PID/stat)

compUser=${modoUser[$cont]}
compNucleo=${modoNucleo[$cont]}

if [ -z $compUser ] || [ -z $compNucleo ];
then
echo 2>/dev/null
else
tiempoTotal2[$cont]=$((${modoUser[$cont]}+${modoNucleo[$cont]}))
tiempoTotal2[$cont]=$((tiempoTotal2[$cont] - tiempoTotal1[$cont]))

stop=$(date +%s.%N)
t=$(echo "scale=10; $stop-$start" | bc 2>/dev/null)

ttHerciosSecs[$cont]=$(echo "scale=10; ((${tiempoTotal2[$cont]}/$t)/$hercios)" | bc 2>/dev/null)

pCPU[$cont]=$(echo "scale=10; ${ttHerciosSecs[$cont]}*100" | bc 2>/dev/null | awk '{printf "%.1f", $0}') 

printf "%-6s %-10s %-7s %-10s %-10s %-10s %-10s %-11s %-10s\n" "$PID" "$user" "$prior" "$memVirtual" "$status" "${pCPU[$cont]}" "$pMem" "$totalTime" "$command" >> ./procs.log

fi 
let cont=cont+1

if [ $cont -eq $totalDir ]; then

echo -e
echo -e "\033[1mTareas\e[m" $totalDir
echo -e KiB Mem: "\033[1mMemoria Total\e[m" $memTotal, "\033[1mMemoria Libre\e[m" $memLibre, "\033[1mMemoria Usada\e[m" $memUsada, "\033[1mMemoria en Buffer/Cache\e[m" $cachBuffer, "\033[1mMemoria Disponible\e[m" $memDisponible
echo -e Mem Intercambio KiB: "\033[1mMemoria Total\e[m" $swapTotal, "\033[1mMemoria Libre\e[m" $swapFree, "\033[1mMemoria Usada\e[m" $swapUse
echo -e "\033[1m%Memoria Usada\e[m" $porcUsada%
echo -e "\033[1mUso CPU\e[m" $porcCPU%
echo -e

printf "\e[7m"
printf "%-6s %-10s %-7s %-10s %-10s %-10s %-10s %-11s %-10s\n" PID USUARIO PR VIRT S %CPU %MEM TIME COMMAND
printf "\e[m"

#Ordenamos el fichero de mayor a menor por la columna 6, ya que es la que corresponde al %CPU
#Una vez ordenados mostramos las 10 primeras lineas del fichero
sort -k6 -nr -k7 -nr < ./procs.log | head -10 >./procsOrdenados.log

cat ./procsOrdenados.log
echo; echo
exit

fi

done
