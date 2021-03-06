

#all: listbox.vala demo.vala resources.c
	#valac demo.vala listbox.vala resources.c --pkg glib-2.0 --pkg gtk+-3.0 --pkg gee-0.8 --gresources=resources.xml --target-glib=2.38 -g -X -w




#all: listbox.vala fm.vala
	#valac fm.vala listbox.vala --pkg gtk+-3.0 --pkg gee-0.8 --target-glib=2.38 -g -X -w


#all: listbox.vala fc.vala
	#valac fc.vala listbox.vala --pkg gtk+-3.0 --pkg pango --pkg gee-0.8 --target-glib=2.38 -g -X -w --vapidir=.


all: listbox.vala gtk-demo.vala resources.c
	valac gtk-demo.vala listbox.vala resources.c --pkg glib-2.0 --pkg gtk+-3.0 --pkg gee-0.8 --gresources=resources.xml --target-glib=2.38 -g -X -w



#all: listbox.vala no-scroll.vala
	#valac no-scroll.vala listbox.vala --pkg gtk+-3.0 --pkg pango --pkg gee-0.8 --target-glib=2.38 -g -X -w --vapidir=.



#all: listbox.vala revealer.vala
	#valac revealer.vala listbox.vala --pkg gtk+-3.0 --pkg gee-0.8 --target-glib=2.38 -g -X -w -D DEBUG

#all: listbox.vala overestimate.vala
	#valac overestimate.vala listbox.vala --pkg gtk+-3.0 --pkg gee-0.8 --target-glib=2.38 -g -X -w


#all: listbox.vala easy.vala
	#valac easy.vala listbox.vala --pkg gtk+-3.0 --pkg gee-0.8 --target-glib=2.38 -g -X -w --save-temps



resources.c: resources.xml demo.ui row.ui tweet-row.ui
	glib-compile-resources resources.xml --target=resources.c --generate-source


