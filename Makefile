all: listbox.vala
	valac listbox.vala --pkg gtk+-3.0 --pkg gee-0.8 -g -X -w --save-temps



demo: listbox.vala demo.vala
	valac demo.vala listbox.vala --pkg gtk+-3.0 --pkg gee-0.8 --pkg libsoup-2.4 -g -X -w
