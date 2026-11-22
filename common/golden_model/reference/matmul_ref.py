import numpy as np

def matmul_reference(a, b):
    a, b = np.asarray(a), np.asarray(b)
    if a.ndim != 2 or b.ndim != 2 or a.shape[1] != b.shape[0]:
        raise ValueError("Incompatible matrices")
    return a @ b

if __name__ == "__main__":
    A = np.array([[1, 2], [3, 4]], dtype=np.int32)
    B = np.array([[5, 6], [7, 8]], dtype=np.int32)
    print(matmul_reference(A, B))   # expect [[19 22] [43 50]]
