/*this file is loaded by OSC_CONSOLE*/
/*reload this file from OSC_CONSOLE with 'reloadjs' or 'rj'*/

/*comments in here must NOT be like //comment */

/*====================================================*/

/*wrappers for calls to exposed functions from oscc*/
/*send osc message. message syntax like in OSC_CONSOLE*/
function send(host,port,message)
{
	oscc.send(host,port,message);
}
/*print to OSC_CONSOLE*/
function p(s)
{
	oscc.p(s);
}

/*get message from store*/
function get(s)
{
	return oscc.get(s);
}

/*helper method to setup poller*/
function setPoller(host,port,osccommand,interval)
{
	oscc.setPoller(host,port,osccommand,interval);
}

function destroyPoller()
{
	oscc.destroyPoller();
}


/*
not yet implemented
use //set
function set(s)
{
	oscc.set(s);
}
*/

function runCmd(s)
{
	oscc.runCmd(s);
}

/*====================================================*/

function test_me()
{
	var a=23;
	p('foo '+a);

	send('127.0.0.1',10001,'//set/a;sfi;a structured cache;88.21;'+a);
	send('127.0.0.1',10001,'/hello;is;23;hallo velo');

	b=get('/a');
	if(b!=null)
	{
		for(var i=0;i<b.length;i++)
		{
			p(b[i]);
		}
	}
}

function send_pong_to(pattern,host,port)
{
	send(host,port,'/pong');
}


var aglobal=42;
function setX(a){aglobal=a;}
function getX(){return aglobal;}



/*pass param 00*/
function t1() 
{
	p('(no param)');
}
/*pass param 01*/
function t2(param1) 
{
	p(param1);
}

/*pass param 10*/
function t3(pattern,host,port)
{
	p(pattern+' '+host+' '+port);
}

/*pass param 11*/
function t4(pattern,host,port,param1)
{
	p(pattern+' '+host+' '+port+' '+param1);
}

function t5()
{
	runCmd('xmessage hello &');
}

/*when this method is available, it will be called when oscc is ready after startup*/
function startupHook()
{
	p("startupHook called");
	send('127.0.0.1',10001,'/oscc/up');
}

/*when this method is available, it will be called when oscc is about to quit*/
function shutdownHook()
{
	p("shutdownpHook called");
	send('127.0.0.1',10001,'/oscc/down');
}


/*
you can import java packages
importPackage(java.awt);
importClass(java.awt.Frame);
...
*/
