all: listbox.vala
	valac listbox.vala --pkg gtk+-3.0 --pkg gee-0.8 -g -X -w
