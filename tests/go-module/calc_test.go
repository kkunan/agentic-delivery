package sample

import "testing"

func TestAdd(t *testing.T) {
	if got := Add(2, 3); got != 5 {
		t.Fatalf("Add(2, 3) = %d, want 5", got)
	}
}

func TestClamp(t *testing.T) {
	t.Run("low", func(t *testing.T) {
		if got := Clamp(-1, 0, 10); got != 0 {
			t.Fatalf("Clamp(-1, 0, 10) = %d, want 0", got)
		}
	})
	t.Run("inside", func(t *testing.T) {
		if got := Clamp(5, 0, 10); got != 5 {
			t.Fatalf("Clamp(5, 0, 10) = %d, want 5", got)
		}
	})
}
