/*module 'LIST' for oscc
browse and select items on touchosc device
//tb/150917
*/

/*
set list items (send to oscc):

oscsend localhost 10001 /LIST/add s '"a","b"'
oscsend localhost 10001 /LIST/append s '"c","d","test me"'

/*=========================================================*/
/*=========================================================*/
/*=========================================================*/

/*
TouchOsc Interface Description

send to device:

screen 1: listview, activate with /1

list title:		/1/title
selected item no:	/1/no/sel
highlighted item no:	/1/no/hl
total items:		/1/no/tot

(0..3)
list lines item text:        /1/li/0    s "text"
list lines item button:      /1/li/0/bt f 0/1
list lines item highlight:   /1/li/0/hl f 0/1 
list lines item led:         /1/li/0/ld f 0/1

from device:

first page:		/1/btns/1/1 f 0/1
prev page:		/1/btns/1/2 f 0/1
next page:		/1/btns/1/3 f 0/1
locate selection:	/1/btns/1/4 f 0/1

first line (index 0):	/1/li/0/bt f 0/1
second line (index 1):	/1/li/1/bt f 0/1
third line (index 2):	/1/li/2/bt f 0/1
fourth line (index 3):	/1/li/3/bt f 0/1


wishlist:
-select list
-drop all lists
-drop specific list
-drop from to index in list
*/

/*configure here*/
touchosc_dev_ip='10.10.10.51';
touchosc_dev_port='9000';

function sendToTouchOscDev(msg)
{
	send(touchosc_dev_ip,touchosc_dev_port,msg);
}

/* ===================================================== */

var LIST={};(function (){

/*tmp*/
var title="Test Me";

var lists_ = [];
var selected_realindex=-1;

var page_=-1; /*zero based, <0 force update*/
var items_per_page_=4;
var total_pages_=1;

/*on page, lines 0 -3*/
var selected_line_=0; /*zero based*/

var highlighted_index_=0;
var selected_index_=0;

/*=========================================================*/
LIST.test = function() 
{
	p("hello from LIST");
};

/*=========================================================*/
LIST.append = function(pattern,host,port,js_string)
{
	var obstr_='var list_new = [' + js_string + '];';

	p(obstr_);

	eval(obstr_);
	var list_joined=lists_[selected_realindex].concat(list_new);
	lists_[selected_realindex]=list_joined;

	page_=-1;
	LIST.display()
};

/*=========================================================*/

LIST.add = function(pattern,host,port,js_string)
{
	var obstr_='var list_new = [' + js_string + '];';

	p(obstr_);

	eval(obstr_);
	lists_.push(list_new);

	highlighted_index_=0;
	selected_index_=0;
	page_=-1;
	total_pages_=1;
	selected_line_=0;

	p("total lists: "+lists_.length);

	/*tmp, set last added list active*/
	selected_realindex++;
	LIST.display()
};

/*=========================================================*/
LIST.display = function()
{
	total_pages_=Math.ceil(lists_[selected_realindex].length / items_per_page_);

	var page_change=0;
	var new_page=Math.floor(highlighted_index_ / items_per_page_);
	if(new_page!=page_)
	{
		page_=new_page;
		page_change=1;
	}
	else
	{
		sendToTouchOscDev('/1/li/'+selected_line_+'/hl/visible;i;0');
	}

	selected_line_=highlighted_index_ % items_per_page_ ;

	p('page #: '+page_+'/'+total_pages_+' line #: '+selected_line_);

	var list_start=page_ * items_per_page_;

	if(page_change==1)
	{
		sendToTouchOscDev('/1/title;s;'+title); /* /// */
		sendToTouchOscDev('/1/no/tot;s;'+lists_[selected_realindex].length);

		for(i=0;i<items_per_page_;i++)
		{
			sendToTouchOscDev('/1/li/'+i+'/hl/visible;i;0');
			sendToTouchOscDev('/1/li/'+i+'/ld;f;0');

			if(list_start+i<lists_[selected_realindex].length)
			{
				sendToTouchOscDev('/1/li/'+i+'/visible;i;1');
				sendToTouchOscDev('/1/li/'+i+'/bt/visible;i;1');
				sendToTouchOscDev('/1/li/'+i+'/ldd/visible;i;1');

				sendToTouchOscDev('/1/li/'+i+';s;'+lists_[selected_realindex][list_start+i]);
			}
			else
			{
				/*fill remaining list slots*/
				sendToTouchOscDev('/1/li/'+i+'/visible;i;0');
				sendToTouchOscDev('/1/li/'+i+'/bt/visible;i;0');
				sendToTouchOscDev('/1/li/'+i+'/ld/visible;i;0');
			}
		}
	}/*end if page_changed==1*/

	sendToTouchOscDev('/1/li/'+selected_line_+'/hl/visible;i;1');
	sendToTouchOscDev('/1/no/hl;s;'+(highlighted_index_+1));
	sendToTouchOscDev('/1/no/sel;s;'+(selected_index_+1));

	if(Math.floor(selected_index_ / items_per_page_) == page_)
	{
		var index_line=selected_index_ % items_per_page_;
		sendToTouchOscDev('/1/li/'+index_line+'/ld;f;1');
	}

};/*end display()*/

/*=========================================================*/
LIST.highlight_next_item = function(pattern,host,port)
{
	highlighted_index_++;
	if(highlighted_index_ > lists_[selected_realindex].length-1)
	{
		highlighted_index_=0;
	}
	LIST.display()
};

/*=========================================================*/
LIST.highlight_prev_item = function(pattern,host,port)
{
	highlighted_index_--;
	if(highlighted_index_ < 0)
	{
		highlighted_index_=lists_[selected_realindex].length-1;
	}
	LIST.display()
};

/*=========================================================*/
LIST.prev_page = function(pattern,host,port,toggle_state)
{
	if(toggle_state<1)
	{
		return;
	}

	var new_page=page_-1;
	if(new_page<0)
	{
		new_page=total_pages_-1;
	}

	highlighted_index_=new_page * items_per_page_;
	LIST.display()
};

/*=========================================================*/
LIST.next_page = function(pattern,host,port,toggle_state)
{
	if(toggle_state<1)
	{
		return;
	}

	var new_page=page_+1;
	if(new_page > total_pages_-1)
	{
		new_page=0;

	}

	highlighted_index_=new_page * items_per_page_;
	LIST.display()
};

/*=========================================================*/
LIST.first_page = function(pattern,host,port,toggle_state)
{
	if(toggle_state<1)
	{
		return;
	}

	highlighted_index_=0;
	LIST.display()
};

/*=========================================================*/
LIST.locate_selection = function(pattern,host,port,toggle_state)
{
	if(toggle_state<1)
	{
		return;
	}

	highlighted_index_=selected_index_;
	LIST.display()
};

/*=========================================================*/
LIST.item_touched = function(pattern,host,port,toggle_state)
{
	if(toggle_state<1)
	{
		return;
	}

	var index_line=-1;
	if(Math.floor(selected_index_ / items_per_page_) == page_)
	{
		index_line=selected_index_ % items_per_page_;
		sendToTouchOscDev('/1/li/'+index_line+'/ld;f;0');
	}

	sendToTouchOscDev('/1/li/'+selected_line_+'/hl/visible;i;0');

	if(pattern=='/1/li/0/bt')
	{
		selected_line_=0;
	}
	else if(pattern=='/1/li/1/bt')
	{
		selected_line_=1;
	}
	else if(pattern=='/1/li/2/bt')
	{
		selected_line_=2;
	}
	else if(pattern=='/1/li/3/bt')
	{
		selected_line_=3;
	}

	selected_index_=page_ * items_per_page_ + selected_line_;
	highlighted_index_=selected_index_;

	sendToTouchOscDev('/1/li/'+selected_line_+'/ld;f;1');
	sendToTouchOscDev('/1/li/'+selected_line_+'/hl/visible;i;1');
	sendToTouchOscDev('/1/no/sel;s;'+(selected_index_+1));
	sendToTouchOscDev('/1/no/hl;s;'+(highlighted_index_+1));
};/*end item_touched()*/

/*=========================================================*/
LIST.select_highlighted_item = function(pattern,host,port)
{
	var index_line=-1;
	if(Math.floor(selected_index_ / items_per_page_) == page_)
	{
		index_line=selected_index_ % items_per_page_;
		sendToTouchOscDev('/1/li/'+index_line+'/bt;f;0');
	}

	selected_index_=highlighted_index_;

	page_=-1;
	LIST.display()
};

})();
/*end mod LIST*/
