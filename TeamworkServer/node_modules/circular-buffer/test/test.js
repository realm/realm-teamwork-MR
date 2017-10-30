var assert = require("chai").assert;
var CircularBuffer = require("../");

describe("CircularBuffer", function () {
	var size = 3;

	it("should be a CircularBuffer", function () {
		var buf = new CircularBuffer(size);
		assert.instanceOf(buf, CircularBuffer);
	});

	it("should have the correct capacity", function () {
		var buf = new CircularBuffer(size);
		assert.equal(buf.capacity(), size);
	});

	it("should correctly return the buffer size", function () {
		var buf = new CircularBuffer(size);
		assert.equal(buf.size(), 0);

		buf.enq(0);
		buf.enq(1);

		assert.equal(buf.size(), 2);

		buf.enq(3);
		buf.enq(4);

		assert.equal(buf.size(), 3);
	});

	it("should enqueue items and get them", function () {
		var buf = new CircularBuffer(size);
		var n = Math.random();

		buf.enq(5);
		buf.enq(n);

		assert.equal(buf.get(0), n);
	});

	it("retrieve multiple values at once", function () {
		var buf = new CircularBuffer(size);

		for (var i = 0; i < 4; i++) {
			buf.enq(i);
		}

		var res = buf.get(0,2); // 3,2,1
		assert.instanceOf(res, Array);
		assert.deepEqual(res, [3, 2, 1]);
	});

	it("should handle partial gets correctly", function () {
		var buf = new CircularBuffer(size);

		for (var i = 0; i < 4; i++) {
			buf.enq(i);
		}

		var res = buf.get(1,2); // 2,1
		assert.instanceOf(res, Array);
		assert.deepEqual(res, [2, 1]);
	});

	it("should convert the current values to an array", function () {
		var buf = new CircularBuffer(size);

		assert.instanceOf(buf.toarray(), Array);
		assert.lengthOf(buf.toarray(), 0);

		buf.enq(42);
		buf.enq("str");
		buf.enq(true);
		buf.enq(Math.PI);

		assert.deepEqual(buf.toarray(), [Math.PI, true, "str"]);
	});

	it("should error when dequeuing on an empty buffer", function () {
		var buf = new CircularBuffer(size);
		try {
			buf.deq();
		} catch (e) { // yay! we caught an error
			return;
		}

		assert.fail("No error after dequeueing empty buffer", "Error after dequeueing empty buffer");
	});

	it("should error when shifting on an empty buffer", function () {
		var buf = new CircularBuffer(size);
		try {
			buf.shift();
		} catch (e) { // yay! we caught an error
			return;
		}

		assert.fail("No error after shifting empty buffer", "Error after shifting empty buffer");
	});

	it("should correctly distinguish push and enq", function () {
		var buf = new CircularBuffer(size);
		buf.enq("mid");
		buf.push("last");
		buf.enq("first");
		assert.deepEqual(buf.toarray(), ["first", "mid", "last"]);
	});

	it("should shift correctly", function () {
		var buf = new CircularBuffer(size);
		buf.push(1);
		buf.push(2);
		buf.push(3);
		buf.push(4);

		assert.deepEqual(buf.shift(), 2);
		assert.deepEqual(buf.toarray(), [3, 4]);
	});

	it("should dequeue and pop correctly", function () {
		var buf = new CircularBuffer(size);
		buf.push(1);
		buf.push(2);
		buf.push(3);
		buf.push(4);

		assert.deepEqual(buf.pop(), 4);
		assert.deepEqual(buf.deq(), 3);
		assert.deepEqual(buf.toarray(), [2]);
	});

	it("should handle the README example correctly", function () {
		var buf = new CircularBuffer(3);
		assert.deepEqual(buf.capacity(), 3);
		buf.enq(1);
		buf.enq(2);
		assert.deepEqual(buf.size(), 2);
		assert.deepEqual(buf.toarray(), [2,1]);
		buf.push(3);
		assert.deepEqual(buf.toarray(), [2,1,3]);
		buf.enq(4);
		assert.deepEqual(buf.size(), 3);
		assert.deepEqual(buf.toarray(), [4,2,1]);
		assert.deepEqual(buf.get(0), 4);
		assert.deepEqual(buf.get(0,2), [4,2,1]);
		assert.deepEqual(buf.toarray(), [4,2,1]);
		assert.deepEqual(buf.deq(), 1);
		assert.deepEqual(buf.toarray(), [4,2]);
		assert.deepEqual(buf.pop(), 2);
		assert.deepEqual(buf.deq(), 4);
		assert.deepEqual(buf.toarray(), []);
		try {
			buf.deq();
		} catch (e) {
			return;
		}
		assert.fail("No error after dequeueing empty buffer", "Error after dequeueing empty buffer");
	});

});
