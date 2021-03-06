#! /bin/bash
# set -xe

# source yq_functions.sh

if [ "$#" -ne 2 ]; then
    printf "Illegal number of parameters\n"
    exit -1
fi

twoColsStart="##2colsstart##"
twoColsRow="##2colsrow##"
twoColsEnd="##2colsend##"

workingdir=$PWD

tmpfile=$1.tmp
currenttmpdir="$(dirname "$tmpfile")"
filenametmp="$(basename -- "$tmpfile")"

case "$1" in
*.md )
        cp $1 $tmpfile
        cd $currenttmpdir
        sed -i "s/<kbd>\(.*\)<\/kbd>/kbd:\[\1\]/g" $filenametmp
        sed -i "s/==\([^=].*[^=]\)==/[.yellow-background]#\1#/g" $filenametmp
        ## translate comments in adoc format before conversion (because pandoc remove it)
        sed -i -e "s/<!-- \(.*\) -->/\n\/\/ \1\n/g" $filenametmp

        pandoc -s -f markdown-smart -t asciidoctor --shift-heading-level-by=-1  $filenametmp -o $2
        
        # go back into working dir
        cd $workingdir
        # fix attributes bad convertion
        sed -i -e "s/\\\{/{/g" $2        
        ;;
*.rst ) 
        cp $1 $tmpfile
        # fix bug with enbeded rst -> go into input folder
        cd $currenttmpdir
        pandoc -s -f rst -t rst $filenametmp -o $2.tmp

        sed -i -e "s/\.\. container:: newslide/<<</g" $2.tmp

        sed -i -e "s/^.. container:: ifeval \(.*\)$/\n\/\/ ifeval \1\n/g" $2.tmp
        sed -i -e "s/^.. container:: end_ifeval$/\n\/\/ end_ifeval \n/g" $2.tmp

        sed -i -e "s/^.. container:: ifdef \(.*\)$/\n\/\/ ifdef \1\n/g" $2.tmp
        sed -i -e "s/^.. container:: end_ifdef$/\n\/\/ end_ifdef \n/g" $2.tmp

        sed -i -e "s/^.. container:: ifndef \(.*\)$/\n\/\/ ifndef \1\n/g" $2.tmp
        sed -i -e "s/^.. container:: end_ifndef$/\n\/\/ end_ifndef \n/g" $2.tmp

        sed -i -e "s/^\([ \t]*\).. container:: sliderow/\1$twoColsStart/g" $2.tmp
        sed -i -e "s/^\([ \t]*\).. container:: slidecol/\1$twoColsRow/g" $2.tmp
        sed -i -e "s/^\([ \t]*\).. container:: endsliderow/\1$twoColsEnd/g" $2.tmp

        sed -i -e "s/^\([ \t]*\).. container:: 2cols/\1$twoColsStart/g" $2.tmp
        sed -i -e "s/^\([ \t]*\).. container:: newcol/\1$twoColsRow/g" $2.tmp
        sed -i -e "s/^\([ \t]*\).. container:: end_2cols/\1$twoColsEnd/g" $2.tmp        

        sed -i -e "s/:download:\`\(.*\)\`/\`\1\`_/g" $2.tmp

        pandoc -s -f rst -t asciidoctor $2.tmp -o $2
        
        rm -f $2.tmp 
        # go back into working dir
        cd $workingdir
        # fix attributes bad convertion
        sed -i -e "s/\\\{/{/g" $2
        # remove text bloc title
        sed -i -e "/^\.Note/d" $2
        sed -i -e "/^\.Warning/d" $2
        sed -i -e "/^\.Tip/d" $2
        sed -i -e "/^\.Caution/d" $2
        sed -i -e "/^\.Important/d" $2
        
        ;;
*.adoc )
        cp $1 $2
        ;;

*)
        printf "extension not supported. only rst,md and adoc.\n"
        exit -1
        ;;
esac
rm -f $tmpfile

# add fullwidth on tables and autowidth on columns
# if [ "$(readVarInYml table.fullwidth false)" = true ]; then sed -i "s/\[cols=/\[%autowidth.stretch,cols=/g" $2 ; fi

# ifeval support
sed -i "s/\/\/ ifeval \(.*\)$/ifeval::\[\1\]/g" $2

# ifdef support
sed -i "s/\/\/ ifdef \(.*\)$/ifdef::\1\[\]/g" $2

# ifndef support
sed -i "s/\/\/ ifndef \(.*\)$/ifndef::\1\[\]/g" $2

sed -i "s/\/\/ end_ifeval/endif::\[\]/g" $2
sed -i "s/\/\/ end_ifdef/endif::\[\]/g" $2
sed -i "s/\/\/ end_ifndef/endif::\[\]/g" $2

# fix image bloc vs inline
sed -i "s/^image:\([^:].*\)\[\([^]]*\)\]$/image::\1[\2]/g" $2

# fix checkbox list
sed -i "s/* ☒ /* [x] /g" $2
sed -i "s/* ☐ /* [ ] /g" $2

# multi columns
sed -i ':a;N;$!ba;s/\/\/ table_hide\n\n\[cols/table_hide\[%autowidth.stretch,frame=none,grid=none,stripes=none,cols/g' $2
sed -i -e 's/table_hide\[\(.*\),options="header",\]/\[\1\]/g' $2
sed -i -e 's/table_hide\(.*\)/\1/g' $2

sed -i -e "s/\([ \t]*\)$twoColsStart/\1\[cols=2*a,%autowidth.stretch,frame=none,grid=none,stripes=none\]\n|===/g" $2
sed -i -e "s/\([ \t]*\)$twoColsRow/\1|/g" $2
sed -i -e "s/\([ \t]*\)$twoColsEnd/\1|===/g" $2
sed -i -e '/^____/d' $2
sed -i ':a;N;$!ba;s/--\n|/|/g' $2
sed -i ':a;N;$!ba;s/--\n\n|==/|==/g' $2

# clear diagram blocs
sed -i -e "s/\[source,graphviz/\[graphviz/g" $2
sed -i -e "s/\[source,mermaid/\[mermaid/g" $2
sed -i -e "s/\[source,plantuml/\[plantuml/g" $2
sed -i -e "s/\[source,vega-lite/\[vegalite/g" $2
sed -i -e "s/\[source,vegalite/\[vegalite/g" $2
sed -i -e "s/\[source,vega/\[vega/g" $2
sed -i -e "s/\[source,gnuplot/\[gnuplot/g" $2

# force break before subtitles
# if [ "$(readVarInYml heading.h2.breakbefore false)" = true ]; then sed -i -e 's/^== /<<<\n== /g' $2 ; fi
# if [ "$(readVarInYml heading.h3.breakbefore false)" = true ]; then sed -i -e 's/^=== /<<<\n=== /g' $2 ; fi
# if [ "$(readVarInYml heading.h4.breakbefore false)" = true ]; then sed -i -e 's/^==== /<<<\n==== /g' $2 ; fi
# if [ "$(readVarInYml heading.h5.breakbefore false)" = true ]; then sed -i -e 's/^===== /<<<\n===== /g' $2 ; fi
# if [ "$(readVarInYml heading.h6.breakbefore false)" = true ]; then sed -i -e 's/^====== /<<<\n====== /g' $2 ; fi

exit 0
