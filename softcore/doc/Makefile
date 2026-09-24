architecture.png: architecture.tex
	pdflatex -interaction=nonstopmode -halt-on-error architecture.tex
	pdftoppm -png -r 200 -singlefile architecture.pdf architecture

clean:
	rm -f architecture.aux architecture.log architecture.pdf
