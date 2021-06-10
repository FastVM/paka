#include <stdio.h>

int count_spaces(char *text) {
    int count = 0;
    while (*text != '\0') {
        if (*text == ' ') {
            count += 1;
        }
        text += 1;
    }
    return count;
}

int count_words(char *text) {
    if (*text == '\0') {
        return 0;
    }
    else {
        return count_spaces(text) + 1;
    }
}

int main() {
    printf("%i\n", count_words("two words"));
}