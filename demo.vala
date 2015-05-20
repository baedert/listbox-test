


class SampleModelItem : GLib.Object {
  public int num;
  public int size;
  public bool checked = false;
  public SampleModelItem (int num, int size) {
    this.num = num;
    this.size = size;
  }
}

[GtkTemplate (ui = "/org/baedert/listbox/row.ui")]
class SampleWidget : Gtk.ListBoxRow {
  [GtkChild]
  private Gtk.Label label;
  [GtkChild]
  private Gtk.CheckButton checkbox;
  public int num;
  public int size;
  private unowned SampleModelItem? item;

  public SampleWidget () {
  }

  private void toggled_callback () {
    this.item.checked = this.checkbox.active;
  }

  public void assign (SampleModelItem item) {
    label.label = "Item %'d".printf (item.num);
    this.item = item;
  }

  public void unassign () {
    checkbox.toggled.disconnect (toggled_callback);
    this.item = null;
  }
}

[GtkTemplate (ui = "/org/baedert/listbox/tweet-row.ui")]
class TweetRow : Gtk.ListBoxRow {
  [GtkChild]
  private Gtk.Label text_label;

  public TweetRow () {
    text_label.label = "asdkfjsdahfsdakjf sdafhsda fgsdag fhgsajkfhsga dhfsga df <a href=\"foobar\">hihi</a>
      asdfsadfsadf asjkdf sajkdfhl asdfjsak df";
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


    list_box.fill_func = (item, widget) => {
      TweetRow? row = (TweetRow) widget;

      assert (item != null);

      if (row == null)
        row = new TweetRow ();

      row.show ();

      return row;

      //SampleWidget sample_widget = (SampleWidget) widget;
      //assert (item != null);

      //if (widget == null)
        //sample_widget = new SampleWidget ();
      //else
        //sample_widget.unassign ();

      //var sample = (SampleModelItem) item;

      //sample_widget.assign (sample);


      //if (sample.num > 25)
        //sample_widget.set_size_request (-1, 100);
      //else
        //sample_widget.set_size_request (-1, 20);


      //sample_widget.num = sample.num;
      //sample_widget.size = (int)model.get_n_items ();

      //sample_widget.show_all ();
      //return sample_widget;
    };


    for (int i = 0; i < 5000; i ++)
      model.append (new SampleModelItem (i, 20 + (i * 10)));

    list_box.set_model (model);

    model_size_label.label = "%'u".printf (model.get_n_items ());
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
