import fs from 'fs'
import path from 'path'
import matter from 'gray-matter'
import { remark } from 'remark'
import html from 'remark-html'

// ---- Types ----

export interface Project {
  slug: string
  title: string
  medium: string
  year: string
  runtime?: string
  description: string
  longDescription?: string
  content: string
  contentHtml?: string
  accentColor?: string
}

export interface Post {
  slug: string
  title: string
  date: string
  category: string
  excerpt: string
  tags?: string[]
  content: string
  contentHtml?: string
}

// ---- Paths ----

const projectsDir = path.join(process.cwd(), 'content', 'projects')
const postsDir = path.join(process.cwd(), 'content', 'posts')

// ---- Projects ----

export function getAllProjects(): Project[] {
  if (!fs.existsSync(projectsDir)) return []
  const filenames = fs.readdirSync(projectsDir).filter(f => f.endsWith('.md'))
  return filenames
    .map(filename => {
      const slug = filename.replace(/\.md$/, '')
      const fullPath = path.join(projectsDir, filename)
      const fileContents = fs.readFileSync(fullPath, 'utf8')
      const { data, content } = matter(fileContents)
      return {
        slug,
        title: data.title ?? slug,
        medium: data.medium ?? 'Film',
        year: data.year ?? '',
        runtime: data.runtime,
        description: data.description ?? '',
        longDescription: data.longDescription,
        content,
        accentColor: data.accentColor,
      } as Project
    })
    .sort((a, b) => (a.year < b.year ? 1 : -1))
}

export async function getProject(slug: string): Promise<Project | null> {
  const fullPath = path.join(projectsDir, `${slug}.md`)
  if (!fs.existsSync(fullPath)) return null
  const fileContents = fs.readFileSync(fullPath, 'utf8')
  const { data, content } = matter(fileContents)

  const processedContent = await remark().use(html).process(content)
  const contentHtml = processedContent.toString()

  return {
    slug,
    title: data.title ?? slug,
    medium: data.medium ?? 'Film',
    year: data.year ?? '',
    runtime: data.runtime,
    description: data.description ?? '',
    longDescription: data.longDescription,
    content,
    contentHtml,
    accentColor: data.accentColor,
  }
}

export function getProjectSlugs(): string[] {
  if (!fs.existsSync(projectsDir)) return []
  return fs
    .readdirSync(projectsDir)
    .filter(f => f.endsWith('.md'))
    .map(f => f.replace(/\.md$/, ''))
}

// ---- Posts ----

export function getAllPosts(): Post[] {
  if (!fs.existsSync(postsDir)) return []
  const filenames = fs.readdirSync(postsDir).filter(f => f.endsWith('.md'))
  return filenames
    .map(filename => {
      const slug = filename.replace(/\.md$/, '')
      const fullPath = path.join(postsDir, filename)
      const fileContents = fs.readFileSync(fullPath, 'utf8')
      const { data, content } = matter(fileContents)
      return {
        slug,
        title: data.title ?? slug,
        date: data.date ?? '',
        category: data.category ?? 'Essay',
        excerpt: data.excerpt ?? '',
        tags: data.tags ?? [],
        content,
      } as Post
    })
    .sort((a, b) => (a.date < b.date ? 1 : -1))
}

export async function getPost(slug: string): Promise<Post | null> {
  const fullPath = path.join(postsDir, `${slug}.md`)
  if (!fs.existsSync(fullPath)) return null
  const fileContents = fs.readFileSync(fullPath, 'utf8')
  const { data, content } = matter(fileContents)

  const processedContent = await remark().use(html).process(content)
  const contentHtml = processedContent.toString()

  return {
    slug,
    title: data.title ?? slug,
    date: data.date ?? '',
    category: data.category ?? 'Essay',
    excerpt: data.excerpt ?? '',
    tags: data.tags ?? [],
    content,
    contentHtml,
  }
}

export function getPostSlugs(): string[] {
  if (!fs.existsSync(postsDir)) return []
  return fs
    .readdirSync(postsDir)
    .filter(f => f.endsWith('.md'))
    .map(f => f.replace(/\.md$/, ''))
}
