# NodeJS Circular Buffer
<p>
	<a href="https://travis-ci.org/tomsmeding/circular-buffer">
		<img src="https://api.travis-ci.org/tomsmeding/circular-buffer.png?branch=master" alt="Travis CI Badge"/>
	</a>
</p>

This is a simple [circular buffer](http://en.wikipedia.org/wiki/Circular_buffer) implementation for NodeJS.

The implementation can function both as a queue (which it's most suited for), and as a (forgetful) stack. Queue functionality uses `enq()` and `deq()`; stack functionality uses `push()` and `pop()`. Values are enqueued at the front of the buffer and dequeued at the back of the buffer; pushing and popping is at the back of the buffer. Indexing is front-to-back: the last-enqueued item has lowest index, which is also the first-pushed item.

## Usage

Below is a sample session with a circular buffer with this package. It should answer most questions.

```node
var CircularBuffer = require("circular-buffer");

var buf = new CircularBuffer(3);
console.log(buf.capacity()); // -> 3
buf.enq(1);
buf.enq(2);
console.log(buf.size()); // -> 2
buf.toarray(); // -> [2,1]
buf.push(3);
buf.toarray(); // -> [2,1,3]
buf.enq(4);
console.log(buf.size()); // -> 3  (despite having added a fourth item!)
buf.toarray(); // -> [4,2,1]
buf.get(0); // -> 4  (last enqueued item is at start of buffer)
buf.get(0,2); // -> [4,2,1]  (2-parameter get takes start and end)
buf.toarray(); // -> [4,2,1]  (equivalent to buf.get(0,buf.size() - 1) )
console.log(buf.deq()); // -> 1
buf.toarray(); // -> [4,2]
buf.pop(); // -> 2  (deq and pop are functionally the same)
buf.deq(); // -> 4
buf.toarray(); // -> []
buf.deq(); // -> throws RangeError("CircularBuffer dequeue on empty buffer")
```

## Functions

- `size()` -> `integer`
  - Returns the current number of items in the buffer.
- `capacity()` -> `integer`
  - Returns the maximum number of items in the buffer (specified when creating it).
- `enq(value)`
  - Enqueue `value` at the front of the buffer
- `deq()` -> `value`
  - Dequeue an item from the back of the buffer; returns that item. Throws `RangeError` if the buffer is empty on invocation.
- `get(idx)` -> `value`
  - Get the value at index `idx`. `0` is the front of the buffer (last-enqueued item, or first-pushed item), `buf.size()-1` is the back of the buffer.
- `get(start,end)` -> `[value]`
  - Gets the values from index `start` up to and including index `end`; returns an array, in front-to-back order. Equivalent to `[buf.get(start),buf.get(start+1),/*etc*/,buf.get(end)]`.
- `toarray()` -> `[value]`
  - Equivalent to `buf.get(0,buf.size() - 1)`: exports all items in the buffer in front-to-back order.

## Testing

To test the package simply run `npm update && npm test` in the package's root folder.
