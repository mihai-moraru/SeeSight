//
// MediaProcessingExtensions.swift
// Runner
//
// Media processing utilities for FastVLM
// Ported from Apple's ml-fastvlm repository
//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import Accelerate
import CoreImage
import MLX
import MLXLMCommon
import MLXVLM

/// Additions to MediaProcessing -- not currently present in mlx-libraries
enum MediaProcessingExtensions {

    // this function is not exported in current mlx-swift-examples -- local copy until it is exposed
    // properly
    public static func apply(_ image: CIImage, processing: UserInput.Processing?) -> CIImage {
        var image = image

        if let resize = processing?.resize {
            let scale = MediaProcessing.bestFitScale(image.extent.size, in: resize)
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }

        return image
    }

    public static func rectSmallerOrEqual(_ extent: CGRect, size: CGSize) -> Bool {
        return extent.width <= size.width && extent.height <= size.height
    }

    public static func centerCrop(_ extent: CGRect, size: CGSize) -> CGRect {
        CGRect(
            x: extent.origin.x + (extent.width - size.width) / 2,
            y: extent.origin.y + (extent.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    public static func centerCrop(_ image: CIImage, size: CGSize) -> CIImage {
        precondition(
            rectSmallerOrEqual(CGRect(origin: .zero, size: size), size: image.extent.size))
        let origin = CGPoint(
            x: image.extent.minX + (image.extent.width - size.width) / 2,
            y: image.extent.minY + (image.extent.height - size.height) / 2
        )
        let rect = CGRect(origin: origin, size: size)
        return image.cropped(to: rect)
    }

    public static func fitIn(_ size: CGSize, shortestEdge: Int) -> CGSize {
        let se = CGFloat(shortestEdge)
        let aspectRatio = size.width / size.height

        let result: CGSize
        if aspectRatio > 1 {
            let newHeight = se
            let newWidth = (newHeight * aspectRatio).rounded()
            result = CGSize(width: newWidth, height: newHeight)
        } else {
            let newWidth = se
            let newHeight = (newWidth / aspectRatio).rounded()
            result = CGSize(width: newWidth, height: newHeight)
        }

        return result
    }

    // version of function from https://github.com/ml-explore/mlx-swift-examples/pull/222
    public static func resampleBicubic(_ image: CIImage, to size: CGSize) -> CIImage {
        // Create a bicubic scale filter

        let yScale = size.height / image.extent.height
        let xScale = size.width / image.extent.width

        let filter = CIFilter.bicubicScaleTransform()
        filter.inputImage = image
        filter.scale = Float(yScale)
        filter.aspectRatio = Float(xScale / yScale)
        let scaledImage = filter.outputImage!

        // Create a rect with the exact dimensions we want
        let exactRect = CGRect(
            x: 0,
            y: 0,
            width: size.width,
            height: size.height
        )
        // Crop to ensure exact dimensions
        return scaledImage.cropped(to: exactRect)
    }

    static let context = CIContext()

    /// Convert the CIImage into a planar 3 channel MLXArray `[1, C, H, W]`.
    ///
    /// The resulting `MLXArray` might not have an evaluated value yet but
    /// can be used in further `MLXArray` operations.
    public static func asPlanarMLXArray(_ image: CIImage) -> MLXArray {
        let w = Int(image.extent.width)
        let h = Int(image.extent.height)

        let rowBytes = w * 4
        let length = rowBytes * h

        var data = Data(count: length)
        data.withUnsafeMutableBytes { ptr in
            context.render(
                image, toBitmap: ptr.baseAddress!, rowBytes: rowBytes,
                bounds: image.extent, format: .RGBAf, colorSpace: nil)
        }

        let array = data.withUnsafeBytes { ptr in
            MLXArray(ptr, [h, w, 4], type: Float32.self)
        }

        // [H, W, C] -> [1, C, H, W], only rgb (no alpha)
        return array[0..., 0..., ..<3]
            .transposed(2, 0, 1)
            .expandedDimensions(axis: 0)
    }
}
