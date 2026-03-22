import { getAllProjects, getAllPosts } from '@/lib/content'
import Win95Desktop from '@/components/Win95Desktop'

export default function Home() {
  const projects = getAllProjects()
  const posts = getAllPosts()

  return (
    <Win95Desktop
      projects={projects.map((p) => ({
        slug: p.slug,
        title: p.title,
        medium: p.medium,
        year: p.year,
        description: p.description,
        content: p.content,
        runtime: p.runtime,
        accentColor: p.accentColor,
      }))}
      posts={posts.map((p) => ({
        slug: p.slug,
        title: p.title,
        date: p.date,
        category: p.category,
        excerpt: p.excerpt,
        content: p.content,
      }))}
    />
  )
}
