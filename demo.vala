


class SampleModelItem : GLib.Object {
  public int num;
  public int size;
  public bool checked = false;
  public SampleModelItem (int num, int size) {
    this.num = num;
    this.size = size;
  }
}

[GtkTemplate (ui = "/org/baedert/listbox/tweet-row.ui")]
class TweetRow : Gtk.ListBoxRow {
  [GtkChild]
  private Gtk.Label text_label;
  [GtkChild]
  private Gtk.Label time_delta_label;
  public int num = 0;

  public TweetRow () {
    text_label.label = "asdkfjsdahfsdakjf sdafhsda fgsdag fhgsajkfhsga dhfsga df <a href=\"foobar\">hihi</a>
      asdfsadfsadf asjkdf sajkdfhl asdfjsak df";
  }

  public void assign (SampleModelItem item) {
    this.num = item.num;
    this.time_delta_label.label = this.num.to_string ();
  }
}


void main (string[] args) {
  Gtk.init (ref args);

  new ModelListBox ();

  var win = new DemoWindow ();

  win.show ();

  Gtk.main ();
}


[GtkTemplate (ui = "/org/baedert/listbox/demo.ui")]
class DemoWindow : Gtk.Window {
  [GtkChild]
  private Gtk.Label used_widgets_label;
  [GtkChild]
  private ModelListBox list_box;
  [GtkChild]
  private Gtk.Label model_size_label;
  [GtkChild]
  private Gtk.Label visible_items_label;
  [GtkChild]
  private Gtk.Label estimated_height_label;
  [GtkChild]
  private Gtk.ScrolledWindow scroller;
  [GtkChild]
  private Gtk.Entry filter_entry;

  private GLib.ListStore model = new GLib.ListStore (typeof (SampleModelItem));


  public DemoWindow () {



    list_box.notify["cur-widgets"].connect (() => {
      used_widgets_label.label = "%'u".printf (list_box.cur_widgets);
    });

    list_box.notify["model-from"].connect (() => {
      visible_items_label.label = "%'d - %'d".printf (list_box.model_from, list_box.model_to);
    });
    list_box.notify["model-to"].connect (() => {
      visible_items_label.label = "%'d - %'d".printf (list_box.model_from, list_box.model_to);
    });

    scroller.get_vadjustment ().value_changed.connect (() => {
      estimated_height_label.label = "%'dpx".printf (list_box.estimated_height);
    });

    filter_entry.notify["text"].connect (filter_text_changed_cb);


    list_box.fill_func = (item, widget) => {
      TweetRow? row = (TweetRow) widget;
      assert (item != null);

      if (row == null)
        row = new TweetRow ();

      row.assign ((SampleModelItem)item);

      row.show ();

      return row;
    };


    for (int i = 0; i < 5000; i ++)
      model.append (new SampleModelItem (i, 20 + (i * 10)));

    list_box.set_model (model);

    model_size_label.label = "%'u".printf (model.get_n_items ());
  }

  private void filter_text_changed_cb () {
    string new_text = filter_entry.text;
    message (new_text);
  }

  [GtkCallback]
  private void remove_selected_cb () {
    for (int i = 0; i < model.get_n_items (); i ++) {
      var item = (SampleModelItem)model.get_object (i);
      if (item.checked) {
        model.remove (i);
        i --;
      }
    }
  }

  [GtkCallback]
  private void remove_all_cb () {
    error ("TODO: Implement");
  }
}
