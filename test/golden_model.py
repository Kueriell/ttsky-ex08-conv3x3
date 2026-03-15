import numpy as np

# 3×3 Gaussian kernel (sum = 16)
GAUSS = np.array(
    [
        [1, 2, 1],
        [2, 4, 2],
        [1, 2, 1],
    ],
    dtype=np.int32,
)


def conv3x3_gaussian(pix9):
    """
    Compute a 3×3 Gaussian convolution on a list of 9 pixels.

    Matches the hardware implementation:
      - multiply by Gaussian kernel
      - sum all weighted terms
      - divide by 16 (right shift by 4)
      - clamp to [0, 255]
    """
    win = np.array(pix9, dtype=np.int32).reshape(3, 3)
    s = int((win * GAUSS).sum())
    y = s // 16
    return max(0, min(255, y))


def conv3x3_single_channel(img9):
    """
    Compute the convolution for a single 3×3 window.

    Parameters:
        img9 : list of 9 pixel values

    Returns:
        8-bit filtered output value
    """
    return conv3x3_gaussian(img9[0:9])
