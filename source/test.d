string test() {
	return "Hello Dworld!";
}


unittest {
	assert(test() == "Hello Dworld!");
}