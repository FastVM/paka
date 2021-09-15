function deep(x) {
	if (x == 0) {
		return 0
	} else {
		return deep(x - 1) + 1
	}
}

console.log(deep(100000))