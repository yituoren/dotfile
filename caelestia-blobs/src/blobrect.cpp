#include "blobrect.hpp"
#include "blobgroup.hpp"

#include <algorithm>
#include <cmath>

BlobRect::BlobRect(QQuickItem* parent)
    : BlobShape(parent) {}

BlobRect::~BlobRect() {
    if (m_group)
        m_group->removeShape(this);
}

void BlobRect::updatePolish() {
    BlobShape::updatePolish();
    if (m_trackBlur || !m_blurRects.isEmpty())
        updateBlurRects();

    if (m_physicsActive) {
        // Check if deformation is visually imperceptible
        float totalDelta = std::abs(m_dm00 - 1.0f) + std::abs(m_dm01) + std::abs(m_dm11 - 1.0f);
        float totalVel = std::abs(m_dmVel00) + std::abs(m_dmVel01) + std::abs(m_dmVel11);

        if (totalDelta < 0.004f && totalVel < 0.05f) {
            // Snap to rest, no visible deformation
            m_dm00 = 1.0f;
            m_dm01 = 0.0f;
            m_dm11 = 1.0f;
            m_dmVel00 = m_dmVel01 = m_dmVel11 = 0.0f;
            m_deformMatrix = QMatrix4x4();
            emit rawDeformMatrixChanged();
            updateCenteredDeformMatrix();
            m_physicsActive = false;
        } else {
            QMetaObject::invokeMethod(
                this,
                [this]() {
                    if (m_physicsActive && m_group)
                        m_group->markDirty();
                },
                Qt::QueuedConnection);
        }
    }
}

void BlobRect::updatePhysics() {
    const QPointF scenePos = mapToScene(QPointF(width() / 2.0, height() / 2.0));

    if (!m_hasPrevPos) {
        m_prevScenePos = scenePos;
        m_elapsed.start();
        m_hasPrevPos = true;
        return;
    }

    const float dt = static_cast<float>(m_elapsed.restart()) / 1000.0f;
    if (dt > 0.1f || dt < 0.001f) {
        m_prevScenePos = scenePos;
        // Still check atRest on skipped frames to avoid getting stuck
        if (m_physicsActive)
            checkAtRest(0.0f);
        return;
    }

    const float velX = static_cast<float>(scenePos.x() - m_prevScenePos.x()) / dt;
    const float velY = static_cast<float>(scenePos.y() - m_prevScenePos.y()) / dt;
    m_prevScenePos = scenePos;

    const float speed = std::sqrt(velX * velX + velY * velY);

    if (!m_physicsActive) {
        if (speed < 5.0f)
            return;
        m_physicsActive = true;
    }

    // Compute target deformation matrix from velocity
    // R(θ) * diag(stretch, compress) * R(θ)^T
    const float kStretchFactor = static_cast<float>(m_deformScale);
    constexpr float kMaxStretch = 0.35f;

    float target00 = 1.0f;
    float target01 = 0.0f;
    float target11 = 1.0f;

    if (speed > 5.0f) {
        const float targetStretch = 1.0f + std::min(speed * kStretchFactor, kMaxStretch);
        const float targetCompress = 1.0f / targetStretch;

        const float cosA = velX / speed;
        const float sinA = velY / speed;
        const float cos2 = cosA * cosA;
        const float sin2 = sinA * sinA;
        const float cs = cosA * sinA;

        target00 = targetStretch * cos2 + targetCompress * sin2;
        target01 = (targetStretch - targetCompress) * cs;
        target11 = targetStretch * sin2 + targetCompress * cos2;
    }

    // Underdamped spring on each matrix component
    const float kStiffness = static_cast<float>(m_stiffness);
    const float kDamping = static_cast<float>(m_damping);

    const float accel00 = -kStiffness * (m_dm00 - target00) - kDamping * m_dmVel00;
    m_dmVel00 += accel00 * dt;
    m_dm00 += m_dmVel00 * dt;

    const float accel01 = -kStiffness * (m_dm01 - target01) - kDamping * m_dmVel01;
    m_dmVel01 += accel01 * dt;
    m_dm01 += m_dmVel01 * dt;

    const float accel11 = -kStiffness * (m_dm11 - target11) - kDamping * m_dmVel11;
    m_dmVel11 += accel11 * dt;
    m_dm11 += m_dmVel11 * dt;

    m_deformMatrix = QMatrix4x4(m_dm00, m_dm01, 0, 0, m_dm01, m_dm11, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
    emit rawDeformMatrixChanged();
    updateCenteredDeformMatrix();

    checkAtRest(speed);
}

void BlobRect::setTopLeftRadius(qreal r) {
    if (!qFuzzyCompare(m_topLeftRadius, r)) {
        m_topLeftRadius = r;
        emit topLeftRadiusChanged();
        if (m_group)
            m_group->markDirty();
    }
}

void BlobRect::setTopRightRadius(qreal r) {
    if (!qFuzzyCompare(m_topRightRadius, r)) {
        m_topRightRadius = r;
        emit topRightRadiusChanged();
        if (m_group)
            m_group->markDirty();
    }
}

void BlobRect::setBottomLeftRadius(qreal r) {
    if (!qFuzzyCompare(m_bottomLeftRadius, r)) {
        m_bottomLeftRadius = r;
        emit bottomLeftRadiusChanged();
        if (m_group)
            m_group->markDirty();
    }
}

void BlobRect::setBottomRightRadius(qreal r) {
    if (!qFuzzyCompare(m_bottomRightRadius, r)) {
        m_bottomRightRadius = r;
        emit bottomRightRadiusChanged();
        if (m_group)
            m_group->markDirty();
    }
}

void BlobRect::cornerRadii(float out[4]) const {
    const auto maxR = static_cast<float>(std::min(width(), height())) * 0.5f;
    const auto base = std::min(static_cast<float>(m_radius), maxR);
    out[0] = std::min(m_topRightRadius >= 0 ? static_cast<float>(m_topRightRadius) : base, maxR);
    out[1] = std::min(m_bottomRightRadius >= 0 ? static_cast<float>(m_bottomRightRadius) : base, maxR);
    out[2] = std::min(m_bottomLeftRadius >= 0 ? static_cast<float>(m_bottomLeftRadius) : base, maxR);
    out[3] = std::min(m_topLeftRadius >= 0 ? static_cast<float>(m_topLeftRadius) : base, maxR);
}

bool BlobRect::isExcluded(const BlobShape* other) const {
    for (const auto& ptr : m_exclude) {
        if (ptr == other)
            return true;
    }
    return false;
}

QQmlListProperty<BlobRect> BlobRect::exclude() {
    return QQmlListProperty<BlobRect>(
        this, nullptr, &excludeAppend, &excludeCount, &excludeAt, &excludeClear, &excludeReplace, &excludeRemoveLast);
}

void BlobRect::excludeAppend(QQmlListProperty<BlobRect>* prop, BlobRect* rect) {
    auto* self = static_cast<BlobRect*>(prop->object);
    self->m_exclude.append(rect);
    if (self->m_group)
        self->m_group->markDirty();
    emit self->excludeChanged();
}

qsizetype BlobRect::excludeCount(QQmlListProperty<BlobRect>* prop) {
    auto* self = static_cast<BlobRect*>(prop->object);
    return self->m_exclude.size();
}

BlobRect* BlobRect::excludeAt(QQmlListProperty<BlobRect>* prop, qsizetype index) {
    auto* self = static_cast<BlobRect*>(prop->object);
    return self->m_exclude.at(index);
}

void BlobRect::excludeClear(QQmlListProperty<BlobRect>* prop) {
    auto* self = static_cast<BlobRect*>(prop->object);
    if (self->m_exclude.isEmpty())
        return;
    self->m_exclude.clear();
    if (self->m_group)
        self->m_group->markDirty();
    emit self->excludeChanged();
}

void BlobRect::excludeReplace(QQmlListProperty<BlobRect>* prop, qsizetype index, BlobRect* rect) {
    auto* self = static_cast<BlobRect*>(prop->object);
    self->m_exclude[index] = rect;
    if (self->m_group)
        self->m_group->markDirty();
    emit self->excludeChanged();
}

void BlobRect::excludeRemoveLast(QQmlListProperty<BlobRect>* prop) {
    auto* self = static_cast<BlobRect*>(prop->object);
    if (self->m_exclude.isEmpty())
        return;
    self->m_exclude.removeLast();
    if (self->m_group)
        self->m_group->markDirty();
    emit self->excludeChanged();
}

void BlobRect::checkAtRest(float speed) {
    constexpr float kEpsilon = 0.002f;
    const bool atRest = std::abs(m_dm00 - 1.0f) < kEpsilon && std::abs(m_dm01) < kEpsilon &&
                        std::abs(m_dm11 - 1.0f) < kEpsilon && std::abs(m_dmVel00) < kEpsilon &&
                        std::abs(m_dmVel01) < kEpsilon && std::abs(m_dmVel11) < kEpsilon && speed < 5.0f;

    if (atRest) {
        m_dm00 = 1.0f;
        m_dm01 = 0.0f;
        m_dm11 = 1.0f;
        m_dmVel00 = 0.0f;
        m_dmVel01 = 0.0f;
        m_dmVel11 = 0.0f;
        m_deformMatrix = QMatrix4x4(); // identity
        emit rawDeformMatrixChanged();
        updateCenteredDeformMatrix();
        m_physicsActive = false;
    }
}

// Use the render pass's cached inverse deformation, corner radii and cubic blend.
// Only the part below gradientTop is translucent and needs compositor blur.
static float roundedDistance(const BlobRectData& r, float x, float y) {
    x -= r.cx + r.offsetX;
    y -= r.cy + r.offsetY;
    const float u = r.invDeform[0] * x + r.invDeform[2] * y;
    const float v = r.invDeform[1] * x + r.invDeform[3] * y;
    const float radius = r.radius[u > 0 ? (v > 0 ? 1 : 0) : (v > 0 ? 2 : 3)];
    const float dx = std::abs(u) - r.hw + radius;
    const float dy = std::abs(v) - r.hh + radius;
    const float px = std::max(dx, 0.f), py = std::max(dy, 0.f);
    return (std::min(std::max(dx, dy), 0.f) + std::sqrt(px * px + py * py) - radius)
        * std::max(r.minEig, 0.01f);
}

void BlobRect::setTrackBlur(bool enabled) {
    if (m_trackBlur == enabled) return;
    m_trackBlur = enabled;
    emit trackBlurChanged();
    polish();
}

void BlobRect::updateBlurRects() {
    QVariantList spans;
    if (m_trackBlur && m_group && m_cachedMyIndex >= 0) {
        const auto& popup = m_cachedRects[m_cachedMyIndex];
        const float k = m_group->smoothing();
        const int left = std::floor(popup.cx - popup.screenHalfX - k);
        const int right = std::ceil(popup.cx + popup.screenHalfX + k);
        const int bottom = std::ceil(std::max(popup.cy + popup.screenHalfY, float(m_group->gradientTop()) + k));
        QRect run;
        for (int y = std::floor(m_group->gradientTop()); y < bottom; ++y) {
            auto inside = [&](int x) {
                float d = roundedDistance(popup, x + 0.5f, y + 0.5f);
                for (int i = 0; i < m_cachedRects.size(); ++i) {
                    if (i == m_cachedMyIndex || (popup.excludeMask & (1 << i))) continue;
                    const float b = roundedDistance(m_cachedRects[i], x + 0.5f, y + 0.5f);
                    const float h = k > 0 ? std::max(0.f, 1.f - std::abs(d - b) / k) : 0.f;
                    d = std::min(d, b) - h * h * h * k / 6.f;
                }
                return d <= 0;
            };
            // The bar and dashboard have one continuous span per translucent row.
            const float dy = y + 0.5f - popup.cy;
            int middle = std::clamp(int(popup.cx - dy * popup.invDeform[2] / popup.invDeform[0]), left, right);
            if (!inside(middle)) {
                // A tilted rounded corner can extend beyond the local vertical centreline.
                while (middle > left && !inside(middle)) --middle;
                if (!inside(middle)) {
                    middle = std::max(left, int(popup.cx));
                    while (middle < right && !inside(middle)) ++middle;
                    if (!inside(middle)) continue;
                }
            }
            int lo = left, hi = middle;
            while (lo < hi) {
                const int x = lo + (hi - lo) / 2;
                if (inside(x)) hi = x; else lo = x + 1;
            }
            const int start = lo;
            lo = middle; hi = right;
            while (lo < hi) {
                const int x = lo + (hi - lo + 1) / 2;
                if (inside(x)) lo = x; else hi = x - 1;
            }
            if (run.left() == start && run.right() == lo && run.bottom() + 1 == y)
                run.setBottom(y);
            else {
                if (!run.isEmpty()) spans.append(run);
                run = QRect(start, y, lo - start + 1, 1);
            }
        }
        if (!run.isEmpty()) spans.append(run);
    }
    if (spans != m_blurRects) {
        m_blurRects.swap(spans);
        emit blurRectsChanged();
    }
}
