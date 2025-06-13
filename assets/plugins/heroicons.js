import { readFileSync, readdirSync } from 'node:fs'
import { basename, join } from 'node:path'

export default ({ matchComponents, theme }) => {
  const iconsDir = join(process.cwd(), 'deps/heroicons/optimized')
  const values = {}
  const icons = [
    ['', '/24/outline'],
    ['-solid', '/24/solid'],
    ['-mini', '/20/solid'],
    ['-micro', '/16/solid'],
  ]
  for (const [suffix, dir] of icons) {
    readdirSync(join(iconsDir, dir)).forEach((file) => {
      const name = basename(file, '.svg') + suffix
      values[name] = { name, fullPath: join(iconsDir, dir, file) }
    })
  }
  matchComponents(
    {
      hero: ({ name, fullPath }) => {
        const content = readFileSync(fullPath)
          .toString()
          .replace(/\r?\n|\r/g, '')
        let size = theme('spacing.6')
        if (name.endsWith('-mini')) {
          size = theme('spacing.5')
        } else if (name.endsWith('-micro')) {
          size = theme('spacing.4')
        }
        return {
          [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
          '-webkit-mask': `var(--hero-${name})`,
          mask: `var(--hero-${name})`,
          'mask-repeat': 'no-repeat',
          'background-color': 'currentColor',
          'vertical-align': 'middle',
          display: 'inline-block',
          width: size,
          height: size,
        }
      },
    },
    { values }
  )
}
