# Fluent AMQP plugins using Qpid

## Client input plugin

This plugin connects as a client and subscribes to an AMQP URL. Messages
received become into fluent events.

Example configuration:

    <source>
      @type amqp_qpid
      url amqp://localhost:5672/fluent-input   # Receive messages from this URL.
      tag amqp-test                            # Base tag.
    </source>

`url` (required): A URL with the host and port to connect to. The path part of the URL is
used as the AMQP link address for the subscribing link.

`tag` (required): The base tag to apply to fluent events. If the `tag` is "X"
then messages with no address will given the tag "X". A message with address "Y"
will get the tag "X.Y". Matching "X.**" will get all the messages, you can match
for messages with specific addresses using "X.something"

`@id` (optional, string): The AMQP connection uses the fluent plugin-id as the AMQP
"container-id". Not usually relevant.

`reconnect_min`, `reconnect_max` (optional, float): Control reconnect attempts.

If the connection fails, the plugin will attempt to reconnect immediately. If
that fails it will wait for `reconnect_min` seconds to try again. If that fails
it will double the delay before trying again, up to a max of `reconnect_max`

The plugin expects messages to contain an AMQP encoded body which can be
represented as JSON. Typically the body is an AMQP map with string keys and
simple values.

# Getting it to work

Build & install proton from http://qpid.apache.org/releases/qpid-proton-0.10/index.html.
There's a problem with the 0.11.0 release (will be ok in 0.11.1) and 0.9 is too old.

There's a bug in the ccache version of swig, if you have both installed do

    sudo mv /usr/lib64/ccache/swig  /usr/lib64/ccache/swig.hide

To install in /usr/local

    cmake . && make install 
    export RUBYLIB=/usr/local/lib64/proton/bindings/ruby
    export LD_LIBRARY_PATH=/usr/local/lib64

You should be good to go.

# TO-DO items.

`qpid_proton_extra.rb` contains things I intend to add to proton for a future
release, meantime they are monkey patched here so this works with qpid-proton 0.10
(There is a problem with the ruby binding in 0.11, I have pushed a fix for 0.11.1)

Tests are *very* slow. I am doing round-trips with one or just a few messages,
using the buffered-output AMQP plugin with flush_interval=0. I suspect this is
the wrong way to test it. Need realistic tests to verify input plugin perforance
is OK.

Tests are dog-ugly, should use the fluent test framework somehow to unit-test
the input and output plugins separately.

Needs more testing for error conditions and performance.

# Futures

Reliability: the input handler acks as soon as it gets a message. We could delay
the acks until after the fluent "emit" call and send a "reject" if the emit
fails so the sender will know the message wasn't logged.

Security: Not tested with SSL or SASL, proton supports them but it might need
extra work to get them going.

The out handler could connect on-demand rather than having a continuous
connection like the in handler.


