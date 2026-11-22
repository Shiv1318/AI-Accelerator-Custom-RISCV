import numpy as np

N, ACC = 2, 20
rng = np.random.default_rng(1)
lines = []

def add(A, B):
    A = np.asarray(A, dtype=np.int32).reshape(N, N)
    B = np.asarray(B, dtype=np.int32).reshape(N, N)
    C = A @ B
    assert np.abs(C).max() < 2**(ACC - 1), "accumulator overflow"
    lines.append(" ".join(map(str, list(A.flatten()) + list(B.flatten()) + list(C.flatten()))))

add([[1, 2], [3, 4]], [[5, 6], [7, 8]])          # known answer
add(np.eye(N), [[9, -3], [4, 100]])               # identity
add(np.zeros((N, N)), [[5, 6], [7, 8]])           # zero
add(np.ones((N, N)), np.ones((N, N)))             # all ones
add(np.full((N, N), -128), np.full((N, N), -128)) # worst-case positive
add(np.full((N, N), 127), np.full((N, N), -128))  # worst-case negative
for _ in range(1000):                             # seeded random
    add(rng.integers(-128, 128, (N, N)), rng.integers(-128, 128, (N, N)))

with open("software/vectors/matmul_2x2.txt", "w") as f:
    f.write("\n".join(lines) + "\n")
print(f"wrote {len(lines)} vectors")
