import CoreGraphics
import simd

struct Homography {
    let matrix: simd_double3x3

    init?(imagePoints: [CGPoint], worldPoints: [CGPoint]) {
        guard imagePoints.count == 4, worldPoints.count == 4 else { return nil }

        var A = [[Double]](repeating: [Double](repeating: 0, count: 8), count: 8)
        var b = [Double](repeating: 0, count: 8)
        for i in 0..<4 {
            let x = Double(imagePoints[i].x), y = Double(imagePoints[i].y)
            let u = Double(worldPoints[i].x), v = Double(worldPoints[i].y)
            A[2*i]     = [x, y, 1, 0, 0, 0, -u*x, -u*y]
            A[2*i + 1] = [0, 0, 0, x, y, 1, -v*x, -v*y]
            b[2*i]     = u
            b[2*i + 1] = v
        }

        guard let h = Self.gaussianSolve(A, b) else { return nil }
        self.matrix = simd_double3x3(rows: [
            SIMD3(h[0], h[1], h[2]),
            SIMD3(h[3], h[4], h[5]),
            SIMD3(h[6], h[7], 1)
        ])
    }

    func project(_ p: CGPoint) -> CGPoint {
        let v = SIMD3(Double(p.x), Double(p.y), 1.0)
        let w = matrix * v
        guard abs(w.z) > 1e-12 else { return .zero }
        return CGPoint(x: w.x / w.z, y: w.y / w.z)
    }

    private static func gaussianSolve(_ A: [[Double]], _ b: [Double]) -> [Double]? {
        let n = A.count
        var m = A
        var y = b
        for i in 0..<n {
            var pivot = i
            for k in (i + 1)..<n where abs(m[k][i]) > abs(m[pivot][i]) { pivot = k }
            m.swapAt(i, pivot)
            y.swapAt(i, pivot)
            if abs(m[i][i]) < 1e-12 { return nil }
            for k in (i + 1)..<n {
                let f = m[k][i] / m[i][i]
                for j in i..<n { m[k][j] -= f * m[i][j] }
                y[k] -= f * y[i]
            }
        }
        var x = [Double](repeating: 0, count: n)
        for i in stride(from: n - 1, through: 0, by: -1) {
            var s = y[i]
            for j in (i + 1)..<n { s -= m[i][j] * x[j] }
            x[i] = s / m[i][i]
        }
        return x
    }

    static func fromServiceBox(imagePoints: [CGPoint]) -> Homography? {
        let world: [CGPoint] = [
            CGPoint(x: 0,     y: 6.40),
            CGPoint(x: 4.115, y: 6.40),
            CGPoint(x: 4.115, y: 0),
            CGPoint(x: 0,     y: 0)
        ]
        return Homography(imagePoints: imagePoints, worldPoints: world)
    }
}
