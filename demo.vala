


// Model {{{

class TweetModel : GLib.ListModel, GLib.Object {
  private Gee.ArrayList<SampleModelItem> items = new Gee.ArrayList<SampleModelItem> ();

  public GLib.Type get_item_type () {
    return typeof (SampleModelItem);
  }

  public uint get_n_items () {
    return items.size;
  }

  public void clear () {
    int size = this.items.size;

    items.clear ();
    this.items_changed (0, size, 0);
  }

  public GLib.Object? get_item (uint position) {
    return items.get ((int)position);
  }

  public void append (SampleModelItem item) {
    this.items.add (item);
  }

  public void insert (int pos, SampleModelItem item) {
    items.insert (pos, item);
    this.items_changed (pos, 0, 1);
  }

  public void shuffle () {
    int s = items.size;
    // Don't reverse the order,
    for (int i = 0; i < s / 2; i ++) {
      var k = this.items.remove_at (i);
      this.items.insert ((int)(GLib.Random.next_int () % (this.items.size - 1)),
                         k);
    }

    // Everything changed
    this.items_changed (0, get_n_items (), get_n_items ());
  }
}

// }}}


// UTIL {{{

string random_text () {
  const int MAX_LENGTH = 600;
  const int MIN_LENGTH = 20;
  StringBuilder b = new StringBuilder ();

  // XXX Should just use a char[] m( m( m(

  int length = GLib.Random.int_range (MIN_LENGTH, MAX_LENGTH);

  for (int i = 0; i < length; i ++) {
    char r_c = (char) (96 + GLib.Random.int_range (0, 128-97));
    b.append_c (r_c);
  }
  //return b.str;
  return "bbb";
}

// }}}

class SampleModelItem : GLib.Object {
  public int num;
  public int size;
  public bool checked = false;
  public string text;

  public SampleModelItem (int num, int size) {
    this.num = num;
    this.size = size;
    this.text = random_text ();
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
    //text_label.label = "asdkfjsdahfsdakjf sdafhsda fgsdag fhgsajkfhsga dhfsga df <a href=\"foobar\">hihi</a>
      //asdfsadfsadf asjkdf sajkdfhl asdfjsak df";
  }

  public void assign (SampleModelItem item) {
    this.num = item.num;
    this.time_delta_label.label = this.num.to_string ();
    this.text_label.label = item.text;
  }

  public void set_label (string s) {
    text_label.label = s;
  }

  public override bool draw (Cairo.Context ct) {
    ct.set_source_rgba (1, 1, 1, 1);
    ct.rectangle (0, 0, get_allocated_width (), get_allocated_height ());
    ct.fill ();
    return base.draw (ct);
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
  private Gtk.Entry filter_entry;
  [GtkChild]
  private Gtk.Switch filter_switch;
  [GtkChild]
  private Gtk.ScrolledWindow scroller;

  private TweetModel model = new TweetModel ();


  public DemoWindow () {

    this.delete_event.connect (() => { Gtk.main_quit (); return false; });


    list_box.notify["cur-widgets"].connect (() => {
      used_widgets_label.label = "%'u (%'u cached, %'u total)"
              .printf (list_box.cur_widgets, list_box.cached_widgets, list_box.total_widgets);
    });

    list_box.notify["model-from"].connect (() => {
      visible_items_label.label = "%'d - %'d".printf (list_box.model_from, list_box.model_to);
    });
    list_box.notify["model-to"].connect (() => {
      visible_items_label.label = "%'d - %'d".printf (list_box.model_from, list_box.model_to);
    });

    list_box.notify["estimated-height"].connect (() => {
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


    try {
			var provider = new Gtk.CssProvider ();
			provider.load_from_data (".list-row { border-bottom: 1px solid alpha(grey, 0.3);}",-1);
			Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (),
																								provider,
																								Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    } catch (GLib.Error e) {
      error (e.message);
    }




    //for (int i = 0; i < 5000; i ++)
    for (int i = 0; i < 15; i ++)
      model.append (new SampleModelItem (i, 20 + (i * 10)));

    list_box.set_model (model);

    model_size_label.label = "%'u".printf (model.get_n_items ());
    model.items_changed.connect (() => {
      model_size_label.label = "%'u".printf (model.get_n_items ());
    });
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
        //model.remove (i);
        i --;
      }
    }
  }

  [GtkCallback]
  private void reverse_order_button_clicked_cb () {
    this.model.shuffle ();
  }

  [GtkCallback]
  private void add_start_button_clicked_cb () {
    int index = 0;
    var item = new SampleModelItem (index, 20  + (int)(GLib.Random.next_int () % 100));
    this.model.insert (index, item);
  }

  [GtkCallback]
  private void add_middle_button_clicked_cb () {
    int index = this.list_box.model_from +
      (this.list_box.model_to - this.list_box.model_from) / 2;

    var item = new SampleModelItem (index, 20  + (int)(GLib.Random.next_int () % 100));
    this.model.insert (index, item);
  }

  [GtkCallback]
  private void add_end_button_clicked_cb () {
    // XXX This fails if the last part of the list ist visible
    int index = (int)this.model.get_n_items ();
    var item = new SampleModelItem (index, 20  + (int)(GLib.Random.next_int () % 100));
    this.model.insert (index, item);
  }

  [GtkCallback]
  private void filter_cb () {
    if (this.filter_switch.active) {
      list_box.filter_func = (item) => {
        assert (item != null);
        var sample = (SampleModelItem) item;

        return sample.num % 2 == 0;
      };
      list_box.refilter ();
    } else {
      list_box.filter_func = null;
      list_box.refilter ();
    }
  }

  [GtkCallback]
  private void remove_all_cb () {
    this.model.clear ();
  }

  [GtkCallback]
  private void debug_cb () {
    this.list_box.print_debug_info ();
  }

  [GtkCallback]
  private void scroll_up_cb () {
    scroller.get_vadjustment ().value --;
  }

  [GtkCallback]
  private void scroll_down_cb () {
    scroller.get_vadjustment ().value ++;
  }
}
